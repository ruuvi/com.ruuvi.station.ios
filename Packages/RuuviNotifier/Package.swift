// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviNotifier",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviNotifier",
            targets: ["RuuviNotifier"]
        ),
        .library(
            name: "RuuviNotifierImpl",
            targets: ["RuuviNotifierImpl"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviLocal"),
        .package(path: "../../Common/RuuviLocalization"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviService"),
        .package(path: "../RuuviNotification"),
    ],
    targets: [
        .target(
            name: "RuuviNotifier",
            dependencies: [
                "RuuviOntology"
            ]
        ),
        .target(
            name: "RuuviNotifierImpl",
            dependencies: [
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviLocalization", package: "RuuviLocalization"),
                "RuuviNotifier",
                "RuuviOntology",
                "RuuviService",
                "RuuviNotification",
            ]
        ),
        .testTarget(
            name: "RuuviNotifierTests",
            dependencies: ["RuuviNotifier"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
