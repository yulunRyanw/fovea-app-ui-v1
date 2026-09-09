// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Fovea",
    platforms: [.macOS(.v14)],
    // Exposed so the prototypes package under Prototypes/ can import Core.
    products: [.library(name: "FoveaCore", targets: ["FoveaCore"])],
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
