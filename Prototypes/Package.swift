// swift-tools-version:5.9
import PackageDescription

// Fovea Lab: front-page prototypes, kept apart from the shipping app in Sources/.
// Depends on the shipping package only for FoveaCore (models, fixtures, geometry).
let package = Package(
    name: "FoveaLab",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "Fovea", path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "FoveaLab",
            dependencies: [.product(name: "FoveaCore", package: "Fovea")],
            path: "FoveaLab"
        ),
    ]
)
