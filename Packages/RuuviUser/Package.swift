// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviUser",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviUser",
            targets: ["RuuviUser"]
        ),
        .library(
            name: "RuuviUserCoordinator",
            targets: ["RuuviUserCoordinator"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RuuviUser"
        ),
        .target(
            name: "RuuviUserCoordinator",
            dependencies: [
                "RuuviUser"
            ]
        ),
        .testTarget(
            name: "RuuviUserTests",
            dependencies: ["RuuviUser", "RuuviUserCoordinator"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
