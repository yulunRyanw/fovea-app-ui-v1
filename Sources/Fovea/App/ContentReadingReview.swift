import SwiftUI
import WebKit

struct ContentReviewSample: Identifiable {
    let id: String
    let title: String
    let source: String
    let markdown: String
    var phase = "completed"
    var images: [HistoryPreviewMaterial] = []
    var imageSources: [String:[String:String]] = [:]
    var expected: [String: Int] = [:]
}

@MainActor @Observable final class ContentReviewState {
    static let shared = ContentReviewState()
    var samples: [ContentReviewSample] = []
    var selected = 0
    var width = 560.0
    var fraction = 1.0
    var playing = false
    var interrupted = false
    var task: Task<Void, Never>?
    var sample: ContentReviewSample? { samples.indices.contains(selected) ? samples[selected] : nil }
    var markdown: String { String((sample?.markdown ?? "").prefix(Int(Double(sample?.markdown.count ?? 0) * fraction))) }
    var phase: String { interrupted ? "interrupted" : fraction < 1 ? "streaming" : sample?.phase ?? "completed" }
    init() {
        let root = URL(fileURLWithPath: "/private/tmp/fovea-reading-native-01a08bc5/preview-data/AnswerContent/fixtures")
        if let golden = try? String(contentsOf: root.appendingPathComponent("sac-answer.md"), encoding: .utf8) {
            samples.append(.init(id:"golden", title:"已认可样例 · 正文与 12 处公式", source:"现有渲染 PRD 的真实回答样例", markdown:golden,
                expected:["inlineMathCount":11,"displayMathCount":1,"degradedFormulaCount":0]))
        }
        for item in ReadingPreviewState.shared.cases where !item.answer.isEmpty {
            samples.append(.init(id:item.id,title:item.label,source:"真实 History · " + item.title,
                markdown:PreviewNativeContent.answer(item.answer),phase:item.status,
                images:item.materials.filter { $0.imagePath != nil },imageSources:PreviewRecordedImages.sources(item.materials)))
        }
        if let sample = samples.first(where:{$0.title == "Codex · 图片与文件"}),
           let material = sample.images.first, let path = material.storedImageName {
            let encoded = path.replacingOccurrences(of:" ",with:"%20")
            samples.append(.init(id:"recorded-image-format",title:"格式检查 · 真实附件图片",source:"历史附件，按 Markdown 图片格式展示",
                markdown:"![" + material.label + "](" + encoded + ")",imageSources:sample.imageSources.merging([encoded:sample.imageSources[path] ?? [:]]){a,_ in a}))
        }
        if let data = try? Data(contentsOf:root.appendingPathComponent("format-cases.json")),
           let json = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
           let cases = json["cases"] as? [[String:Any]] {
            for item in cases {
                guard let id = item["id"] as? String, let title = item["title"] as? String, let markdown = item["markdown"] as? String else { continue }
                let expected = (item["expected"] as? [String:Any] ?? [:]).compactMapValues { $0 as? Int }
                samples.append(.init(id:id,title:"规范用例 · " + title,source:"既有 PRD 格式用例 · " + id,
                    markdown:markdown,phase:item["phase"] as? String ?? "completed",expected:expected))
            }
        }
    }
    func stop() { task?.cancel(); task = nil; playing = false }
    func select(_ value: Int) { stop(); selected = value; fraction = 1; interrupted = false }
    func play() {
        stop(); fraction = 0; interrupted = false; playing = true
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.fraction < 1 {
                do { try await Task.sleep(for:.milliseconds(120)) } catch { return }
                self.fraction = min(1,self.fraction + 0.015)
            }
            self?.playing = false
        }
    }
}

/// Test controls are outside the product surface; the black reading area has no action toolbar.
struct ContentReadingReview: View {
    @Bindable var review = ContentReviewState.shared
    @State private var height: CGFloat = 40
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing:0) {
                Color.black.frame(height:32)
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        if let sample = review.sample {
                            if review.markdown.isEmpty {
                                Text("等待正文…").font(Tokens.Type_.body).foregroundStyle(.secondary)
                            }
                            content(sample).frame(height:height).id(sample.id)
                            if review.fraction == 1, !sample.images.isEmpty {
                                Divider()
                                Text("随问题提供的图片").font(Tokens.Type_.caption).foregroundStyle(.secondary)
                                ForEach(sample.images) { material in
                                    if let path = material.imagePath, let image = NSImage(contentsOfFile:path) {
                                        Image(nsImage:image).resizable().scaledToFit().frame(maxWidth:.infinity)
                                            .accessibilityLabel(material.label)
                                        Text(material.label).font(Tokens.Type_.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text(material.label + " · 图片内容不可用").foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }.padding(24).frame(maxWidth:.infinity,alignment:.leading)
                }.frame(height:530)
                Color.black.frame(height:20)
            }.frame(width:review.width).background(.black)
                .clipShape(IslandShape(topRadius:12,bottomRadius:22)).environment(\.colorScheme,.dark)
            VStack(alignment:.leading,spacing:10) {
                Picker("正文样例",selection:Binding(get:{review.selected},set:{review.select($0)})) {
                    ForEach(review.samples.indices,id:\.self) { Text(review.samples[$0].title).tag($0) }
                }
                HStack {
                    Picker("阅读宽度",selection:$review.width) { Text("窄 · 360").tag(360.0); Text("标准 · 560").tag(560.0); Text("宽 · 720").tag(720.0) }
                    Button(review.playing ? "暂停" : "逐段显示") { review.playing ? review.stop() : review.play() }
                    Button("中断显示") { review.stop(); review.interrupted = true }
                    Button("完整正文") { review.stop(); review.fraction = 1; review.interrupted = false }
                }
                Slider(value:Binding(get:{review.fraction},set:{review.stop();review.interrupted=false;review.fraction=$0}),in:0...1)
                Text((review.sample?.source ?? "") + " · " + (review.interrupted ? "中断" : review.fraction < 1 ? "分段展示" : "完整显示"))
                Text("仅评审内容显示。分段使用原文前缀，不代表历史生成速度；规范用例与真实 History 分开标注。")
            }.font(Tokens.Type_.caption).padding(.horizontal,30)
        }.padding(.top,20)
    }
    private func content(_ sample: ContentReviewSample) -> CodexAnswerContent {
        var content = CodexAnswerContent(messageID:sample.id,markdown:review.markdown,status:review.phase,height:$height)
        content.imageSources = sample.imageSources
        return content
    }
}
