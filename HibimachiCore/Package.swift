// swift-tools-version: 6.0
// Game rules and persistence live here, outside the Xcode app target, so they can be
// built and tested with plain `swift test` (also on Linux CI) without SpriteKit/SwiftUI.
import PackageDescription

let package = Package(
    name: "HibimachiCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HibimachiCore", targets: ["HibimachiCore"]),
        .library(name: "HibimachiStorage", targets: ["HibimachiStorage"]),
    ],
    targets: [
        .target(name: "HibimachiCore"),
        .target(name: "HibimachiStorage", dependencies: ["HibimachiCore"]),
        .testTarget(name: "HibimachiCoreTests", dependencies: ["HibimachiCore"]),
        .testTarget(name: "HibimachiStorageTests", dependencies: ["HibimachiStorage"]),
    ]
)
