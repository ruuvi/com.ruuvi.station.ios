// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCloud",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
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
        .package(url: "https://github.com/rinat-enikeev/BTKit", .upToNextMinor(from: "0.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviUser")
    ],
    targets: [
        .target(
            name: "RuuviCloud",
            dependencies: [
                "Future",
                "RuuviOntology",
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
