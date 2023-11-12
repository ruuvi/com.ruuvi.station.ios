// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviLocation",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviLocation",
            targets: ["RuuviLocation"]
        ),
        .library(
            name: "RuuviLocationService",
            targets: ["RuuviLocationService"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology")
    ],
    targets: [
        .target(
            name: "RuuviLocation",
            dependencies: [
                "Future",
                "RuuviOntology"
            ]
        ),
        .target(
            name: "RuuviLocationService",
            dependencies: [
                "RuuviLocation",
                "Future",
                "RuuviOntology"
            ]
        ),
        .testTarget(
            name: "RuuviLocationTests",
            dependencies: ["RuuviLocation"])
    ]
)
