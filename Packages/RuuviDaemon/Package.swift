// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDaemon",
    platforms: [.macOS(.v10_15), .iOS(.v10)],
    products: [
        .library(
            name: "RuuviDaemon",
            targets: ["RuuviDaemon"])
    ],
    dependencies: [
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService")
    ],
    targets: [
        .target(
            name: "RuuviDaemon",
            dependencies: [
                "RuuviLocal",
                "RuuviService"
            ]
        ),
        .testTarget(
            name: "RuuviDaemonTests",
            dependencies: ["RuuviDaemon"])
    ]
)
