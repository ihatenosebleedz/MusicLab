// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MusicLab",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        // An xtool project should contain exactly one library product,
        // representing the main app.
        .library(
            name: "MusicLab",
            targets: ["MusicLab"]
        ),
    ],
    targets: [
        .target(
            name: "MusicLabCore"
        ),
        .target(
            name: "MusicLab",
            dependencies: ["MusicLabCore"]
        ),
        .testTarget(
            name: "MusicLabCoreTests",
            dependencies: ["MusicLabCore"]
        ),
    ]
)
