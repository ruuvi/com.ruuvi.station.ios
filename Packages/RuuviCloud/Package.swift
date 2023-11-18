// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCloud",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviCloud",
            targets: ["RuuviCloud"]),
        .library(
            name: "RuuviCloudApi",
            targets: ["RuuviCloudApi"]),
        .library(
            name: "RuuviCloudPure",
            targets: ["RuuviCloudPure"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(url: "https://github.com/ruuvi/BTKit", .upToNextMinor(from: "0.4.3")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviUser"),
        .package(path: "../RuuviPool")
    ],
    targets: [
        .target(
            name: "RuuviCloud",
            dependencies: [
                "Future",
                "RuuviOntology",
                "RuuviPool",
                "RuuviUser"
            ]
        ),
        .target(
            name: "RuuviCloudApi",
            dependencies: [
                "RuuviCloud",
                "RuuviOntology",
                "Future",
                "BTKit"
            ]
        ),
        .target(
            name: "RuuviCloudPure",
            dependencies: [
                "RuuviCloud",
                "RuuviCloudApi",
                "RuuviOntology",
                "RuuviUser",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviCloudTests",
            dependencies: ["RuuviCloud"])
    ]
)
