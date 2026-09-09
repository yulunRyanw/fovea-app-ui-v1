import AVFoundation
import Speech
import FoveaCore

// Real microphone level and on-device transcription. One AVAudioEngine feeds both: the
// meter shapes the level for the waveform, the transcriber forwards buffers to Speech.
// Only used when Fovea runs as a bundle (usage strings) or with `--demo island-real`.

/// Owns the input tap. Clients retain it while they need audio.
@MainActor
final class AudioCaptureSession {
    static let shared = AudioCaptureSession()

    private let engine = AVAudioEngine()
    private var clients: Set<String> = []
    private var levelHandlers: [String: (Float) -> Void] = [:]
    private var bufferHandlers: [String: (AVAudioPCMBuffer) -> Void] = [:]

    func attach(_ client: String, level: ((Float) -> Void)? = nil, buffer: ((AVAudioPCMBuffer) -> Void)? = nil) throws {
        if let level { levelHandlers[client] = level }
        if let buffer { bufferHandlers[client] = buffer }
        clients.insert(client)
        try startIfNeeded()
    }

    func detach(_ client: String) {
        clients.remove(client)
        levelHandlers[client] = nil
        bufferHandlers[client] = nil
        if clients.isEmpty { stop() }
    }

    private func startIfNeeded() throws {
        guard !engine.isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw ServiceUnavailable("No microphone is available.", recovery: .openSettings(.microphone))
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let level = AudioCaptureSession.level(of: buffer)
            DispatchQueue.main.async {
                guard let self else { return }
                for handler in self.levelHandlers.values { handler(level) }
                for handler in self.bufferHandlers.values { handler(buffer) }
            }
        }
        engine.prepare()
        try engine.start()
    }

    private func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// RMS → dB → 0…1 through a speech-tuned window (−35…−20 dB), with a visual boost.
    /// The curve comes from OpenDictation (MIT); it makes quiet speech visibly move.
    private nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 1e-7))
        let minDb: Float = -35, maxDb: Float = -20
        let clamped = min(db, maxDb)
        let amplitude = pow(10, 0.05 * clamped)
        let lo = pow(10, 0.05 * minDb), hi = pow(10, 0.05 * maxDb)
        let normalized = max(0, (amplitude - lo) / (hi - lo))
        return min(pow(normalized, 0.5) * 2.5, 1)
    }
}

/// Live input level for the waveform.
@MainActor
final class AVAudioLevelMeter: AudioLevelMetering {
    private let client = "meter"
    private var continuation: AsyncStream<Float>.Continuation?
    private var smoothed: Float = 0

    @MainActor
    func start() async throws -> AsyncStream<Float> {
        guard await Self.requestMicrophone() else {
            throw ServiceUnavailable("Fovea needs microphone access to listen.", recovery: .openSettings(.microphone))
        }
        let stream = AsyncStream<Float>(bufferingPolicy: .bufferingNewest(1)) { self.continuation = $0 }
        try AudioCaptureSession.shared.attach(client, level: { [weak self] level in
            guard let self else { return }
            self.smoothed = self.smoothed * 0.2 + level * 0.8
            self.continuation?.yield(self.smoothed)
        })
        return stream
    }

    @MainActor
    func stop() {
        AudioCaptureSession.shared.detach(client)
        continuation?.finish()
        continuation = nil
    }

    static func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }
}

/// On-device speech recognition fed by the shared capture session.
@MainActor
final class SpeechTranscriber: Transcribing {
    private let client = "speech"
    private let recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<TranscriptChunk, Error>.Continuation?
    private var lastText = ""

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    @MainActor
    func start() async throws -> AsyncThrowingStream<TranscriptChunk, Error> {
        try await prepare()
        let stream = makeStream()
        try AudioCaptureSession.shared.attach(client, buffer: { [weak self] buffer in
            self?.request?.append(buffer)
        })
        return stream
    }

    @MainActor
    func finish() {
        AudioCaptureSession.shared.detach(client)
        request?.endAudio()
    }

    @MainActor
    func cancel() {
        AudioCaptureSession.shared.detach(client)
        task?.cancel()
        task = nil
        request = nil
        continuation?.finish()
        continuation = nil
    }

    // MARK: -

    @MainActor
    private func prepare() async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw ServiceUnavailable("Speech recognition isn’t available on this Mac.", recovery: .none)
        }
        guard await Self.requestSpeech() else {
            throw ServiceUnavailable("Fovea needs Speech Recognition access to transcribe.",
                                     recovery: .openSettings(.speechRecognition))
        }
        task?.cancel()
        task = nil
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.taskHint = .dictation
        self.request = request
        lastText = ""
    }

    @MainActor
    private func makeStream() -> AsyncThrowingStream<TranscriptChunk, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            guard let recognizer, let request else { continuation.finish(); return }
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.lastText = text
                    if result.isFinal {
                        continuation.yield(.final(text))
                        continuation.finish()
                    } else {
                        continuation.yield(.partial(text))
                    }
                }
                if let error {
                    // Speech reports "no speech" as an error after endAudio; treat what we have as final.
                    if !self.lastText.isEmpty {
                        continuation.yield(.final(self.lastText))
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: ServiceUnavailable(Self.message(for: error), recovery: .retry))
                    }
                }
            }
        }
    }

    private static func message(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "kAFAssistantErrorDomain" || ns.domain == "kLSRErrorDomain" { return "Didn’t catch that." }
        return "Transcription failed."
    }

    static func requestSpeech() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .notDetermined:
            return await withCheckedContinuation { c in
                SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
            }
        default: return false
        }
    }
}
