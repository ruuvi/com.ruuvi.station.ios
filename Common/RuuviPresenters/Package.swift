// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPresenters",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviPresenters",
            targets: ["RuuviPresenters"]
        )
    ],
    dependencies: [.package(path: "../RuuviLocalization")],
    targets: [
        .target(
            name: "RuuviPresenters",
            dependencies: [.product(name: "RuuviLocalization", package: "RuuviLocalization")]
        ),
        .testTarget(
            name: "RuuviPresentersTests",
            dependencies: ["RuuviPresenters"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
