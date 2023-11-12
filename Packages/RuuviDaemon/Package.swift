// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDaemon",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviDaemon",
            targets: ["RuuviDaemon"]),
        .library(
            name: "RuuviDaemonCloudSync",
            targets: ["RuuviDaemonCloudSync"]),
        .library(
            name: "RuuviDaemonOperation",
            targets: ["RuuviDaemonOperation"]),
        .library(
            name: "RuuviDaemonBackground",
            targets: ["RuuviDaemonBackground"]),
        .library(
            name: "RuuviDaemonRuuviTag",
            targets: ["RuuviDaemonRuuviTag"]),
        .library(
            name: "RuuviDaemonVirtualTag",
            targets: ["RuuviDaemonVirtualTag"])
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService"),
        .package(path: "../RuuviVirtual"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviReactor"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviNotifier"),
        .package(path: "../RuuviNotification"),
        .package(url: "https://github.com/ruuvi/BTKit", .upToNextMinor(from: "0.4.3"))
    ],
    targets: [
        .target(
            name: "RuuviDaemon",
            dependencies: [
                "RuuviLocal",
                "RuuviService",
                "RuuviVirtual",
                "RuuviStorage",
                "RuuviReactor",
                "RuuviPool",
                "RuuviPersistence",
                "RuuviNotifier",
                "BTKit"
            ]
        ),
        .target(
            name: "RuuviDaemonCloudSync",
            dependencies: [
                "RuuviDaemon",
                "RuuviLocal",
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviDaemonOperation",
            dependencies: [
                "RuuviDaemon",
                "RuuviNotifier",
                "RuuviOntology",
                "RuuviVirtual"
            ]
        ),
        .target(
            name: "RuuviDaemonBackground",
            dependencies: [
                "RuuviDaemon",
                "RuuviDaemonOperation"
            ]
        ),
        .target(
            name: "RuuviDaemonVirtualTag",
            dependencies: [
                "RuuviDaemon",
                "RuuviDaemonOperation"
            ]
        ),
        .target(
            name: "RuuviDaemonRuuviTag",
            dependencies: [
                "RuuviDaemon",
                "RuuviDaemonOperation",
                "RuuviNotification"
            ]
        ),
        .testTarget(
            name: "RuuviDaemonTests",
            dependencies: ["RuuviDaemon"])
    ]
)
