// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOnboard",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviOnboard",
            targets: ["RuuviOnboard"]
        )
    ],
    dependencies: [
        .package(path: "../../Common/RuuviLocalization"),
        .package(path: "../../Packages/RuuviUser"),
    ],
    targets: [
        .target(
            name: "RuuviOnboard",
            dependencies: [
                .product(name: "RuuviLocalization", package: "RuuviLocalization"), "RuuviUser",
            ]
        ),
        .testTarget(
            name: "RuuviOnboardTests",
            dependencies: ["RuuviOnboard", .product(name: "RuuviUser", package: "RuuviUser")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
