// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCore",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        .library(
            name: "RuuviCore",
            targets: ["RuuviCore"]
        ),
        .library(
            name: "RuuviCoreImage",
            targets: ["RuuviCoreImage"]
        ),
        .library(
            name: "RuuviCoreLocation",
            targets: ["RuuviCoreLocation"]
        ),
        .library(
            name: "RuuviCoreDiff",
            targets: ["RuuviCoreDiff"]
        ),
        .library(
            name: "RuuviCorePN",
            targets: ["RuuviCorePN"]
        ),
        .library(
            name: "RuuviCorePermission",
            targets: ["RuuviCorePermission"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0"))
    ],
    targets: [
        .target(
            name: "RuuviCore",
            dependencies: ["Future"]
        ),
        .target(
            name: "RuuviCoreImage",
            dependencies: ["RuuviCore"]
        ),
        .target(
            name: "RuuviCoreDiff",
            dependencies: ["RuuviCore"]
        ),
        .target(
            name: "RuuviCorePN",
            dependencies: ["RuuviCore"]
        ),
        .target(
            name: "RuuviCorePermission",
            dependencies: ["RuuviCore"]
        ),
        .target(
            name: "RuuviCoreLocation",
            dependencies: ["RuuviCore", "Future"]
        ),
        .testTarget(
            name: "RuuviCoreTests",
            dependencies: ["RuuviCore"]
        ),
    ]
)
