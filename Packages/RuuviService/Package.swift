// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviService",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviService",
            targets: ["RuuviService"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviRepository"),
        .package(path: "../RuuviCore")
    ],
    targets: [
        .target(
            name: "RuuviService",
            dependencies: [
                "Future",
                "RuuviOntology",
                "RuuviStorage",
                "RuuviCloud",
                "RuuviPool",
                "RuuviLocal",
                "RuuviRepository",
                "RuuviCore"
            ]
        ),
        .testTarget(
            name: "RuuviServiceTests",
            dependencies: ["RuuviService"])
    ]
)
