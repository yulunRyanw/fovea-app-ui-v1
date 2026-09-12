import Foundation
// Exact production result and evaluation policy, with preview-owned allowed roots.
enum QuickAnswerArtifactOpenResult: Equatable {
    case opened
    case missing
    case outsideAllowedRoots
    case notAFile
    case blockedKind(String)
    case failed

    var messageKey: String? {
        switch self {
        case .opened: return nil
        case .missing: return "qa.artifact.missing"
        case .outsideAllowedRoots: return "qa.artifact.outsideWorkspace"
        case .notAFile: return "qa.artifact.notAFile"
        case .blockedKind: return "qa.artifact.blockedKind"
        case .failed: return "qa.artifact.openFailed"
        }
    }
}

enum PreviewArtifactPolicy {
    static let refusedExtensions: Set<String> = [
        "app", "command", "sh", "bash", "zsh", "csh", "pkg", "mpkg", "dmg",
        "scpt", "scptd", "applescript", "workflow", "terminal", "shortcut",
        "jar", "js", "jse", "vbs", "vbe", "wsf", "wsh", "msi", "exe", "bat",
        "cmd", "com", "scr", "dylib", "so", "kext", "prefpane", "action", "xip",
    ]

    static func evaluate(
        path: String,
        allowedRoots: [String],
        fileManager: FileManager = .default
    ) -> QuickAnswerArtifactOpenResult {
        guard path.hasPrefix("/"), !path.contains("\0") else { return .notAFile }
        let resolved = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolved.path, isDirectory: &isDirectory) else {
            return .missing
        }
        guard !isDirectory.boolValue else { return .notAFile }
        let ext = resolved.pathExtension.lowercased()
        if refusedExtensions.contains(ext) { return .blockedKind(ext) }
        // A bundle-shaped directory is caught above; an extensionless binary
        // is refused too because nothing identifies it as a document.
        guard !ext.isEmpty else { return .blockedKind("") }
        let contained = allowedRoots.contains { root in
            resolved.path == root || resolved.path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
        }
        guard contained else { return .outsideAllowedRoots }
        return .opened
    }

}
