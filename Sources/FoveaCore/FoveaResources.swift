import Foundation

/// Access to bundled images and fixtures. Both the app and the tests read from here.
public enum FoveaResources {
    public static let bundle: Bundle = Bundle.module

    /// URL of a bundled resource given a path relative to `Resources/`, e.g. `Photos/mountain.jpg`.
    /// SwiftPM copies the folder as `<bundle>/Resources/...`; an app wrapper may put it under
    /// `Contents/Resources`, so both roots are checked.
    public static func url(_ relativePath: String) -> URL? {
        let roots = [bundle.bundleURL, bundle.resourceURL].compactMap { $0 }
        for root in roots {
            let url = root.appendingPathComponent("Resources").appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
