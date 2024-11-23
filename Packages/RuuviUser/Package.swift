// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviUser",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
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
                "KeychainAccess"
            ]
        ),
        .testTarget(
            name: "RuuviUserTests",
            dependencies: ["RuuviUser"]
        ),
    ]
)
