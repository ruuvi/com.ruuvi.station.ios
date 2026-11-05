// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCore",
    platforms: [.iOS(.v16)],
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
    dependencies: [],
    targets: [
        .target(
            name: "RuuviCore",
            dependencies: []
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
            dependencies: ["RuuviCore"]
        ),
        .testTarget(
            name: "RuuviCoreTests",
            dependencies: [
                "RuuviCore", "RuuviCoreDiff", "RuuviCoreImage", "RuuviCoreLocation",
                "RuuviCorePermission", "RuuviCorePN",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
