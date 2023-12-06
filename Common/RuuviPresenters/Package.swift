// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPresenters",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviPresenters",
            targets: ["RuuviPresenters"]
        )
    ],
    targets: [
        .target(
            name: "RuuviPresenters",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "RuuviPresentersTests",
            dependencies: ["RuuviPresenters"]
        )
    ]
)
