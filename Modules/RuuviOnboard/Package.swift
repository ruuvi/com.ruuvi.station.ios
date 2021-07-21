// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOnboard",
    defaultLocalization: "en",
    platforms: [.iOS(.v11), .macOS(.v10_15)],
    products: [
        .library(
            name: "RuuviOnboard",
            targets: ["RuuviOnboard"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RuuviOnboard",
            dependencies: []),
        .testTarget(
            name: "RuuviOnboardTests",
            dependencies: ["RuuviOnboard"])
    ]
)
