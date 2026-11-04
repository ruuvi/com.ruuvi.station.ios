// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDaemon",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviDaemon",
            targets: ["RuuviDaemon"]
        ),
        .library(
            name: "RuuviDaemonCloudSync",
            targets: ["RuuviDaemonCloudSync"]
        ),
        .library(
            name: "RuuviDaemonOperation",
            targets: ["RuuviDaemonOperation"]
        ),
        .library(
            name: "RuuviDaemonBackground",
            targets: ["RuuviDaemonBackground"]
        ),
        .library(
            name: "RuuviDaemonRuuviTag",
            targets: ["RuuviDaemonRuuviTag"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviReactor"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviNotifier"),
        .package(path: "../RuuviNotification"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
    ],
    targets: [
        .target(
            name: "RuuviDaemon",
            dependencies: [
                "RuuviLocal",
                "RuuviService",
                "RuuviStorage",
                "RuuviReactor",
                "RuuviPool",
                "RuuviPersistence",
                "RuuviNotifier",
                "BTKit",
            ]
        ),
        .target(
            name: "RuuviDaemonCloudSync",
            dependencies: [
                "RuuviDaemon",
                "RuuviLocal",
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviDaemonOperation",
            dependencies: [
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                "RuuviDaemon",
                "RuuviNotifier",
                "RuuviOntology",
            ]
        ),
        .target(
            name: "RuuviDaemonBackground",
            dependencies: [
                "RuuviDaemon",
                "RuuviDaemonOperation",
            ]
        ),
        .target(
            name: "RuuviDaemonRuuviTag",
            dependencies: [
                .product(name: "RuuviNotifier", package: "RuuviNotifier"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPersistence", package: "RuuviPersistence"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviReactor", package: "RuuviReactor"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                "RuuviDaemon",
                "RuuviDaemonOperation",
                "RuuviNotification",
                "RuuviLocal",
                "RuuviService",
            ]
        ),
        .testTarget(
            name: "RuuviDaemonTests",
            dependencies: ["RuuviDaemon", "RuuviDaemonRuuviTag"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
