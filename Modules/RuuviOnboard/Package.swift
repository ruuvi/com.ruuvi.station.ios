// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOnboard",
    defaultLocalization: "en",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "RuuviOnboard",
            targets: ["RuuviOnboard"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/RuuviUser")
    ],
    targets: [
        .target(
            name: "RuuviOnboard",
            dependencies: ["RuuviUser"]
        ),
        .testTarget(
            name: "RuuviOnboardTests",
            dependencies: ["RuuviOnboard"]
        ),
    ]
)
