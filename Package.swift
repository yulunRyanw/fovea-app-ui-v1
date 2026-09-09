// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fovea",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure models, fixtures and logic. No SwiftUI / AppKit.
        .target(
            name: "FoveaCore",
            path: "Sources/FoveaCore",
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "Fovea",
            dependencies: ["FoveaCore"],
            path: "Sources/Fovea"
        ),
        .testTarget(
            name: "FoveaCoreTests",
            dependencies: ["FoveaCore"],
            path: "Tests/FoveaCoreTests"
        ),
    ]
)
