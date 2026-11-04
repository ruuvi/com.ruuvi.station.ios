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
    dependencies: [
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.1")
    ],
    targets: [
        .target(
            name: "RuuviUser"
        ),
        .target(
            name: "RuuviUserCoordinator",
            dependencies: [
                "RuuviUser",
                "KeychainAccess"
            ]
        ),
        .testTarget(
            name: "RuuviUserTests",
            dependencies: ["RuuviUser"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
