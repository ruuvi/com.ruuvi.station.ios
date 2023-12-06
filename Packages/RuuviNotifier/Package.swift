// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviNotifier",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviNotifier",
            targets: ["RuuviNotifier"]),
        .library(
            name: "RuuviNotifierImpl",
            targets: ["RuuviNotifierImpl"])
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviService"),
        .package(path: "../RuuviNotification")
    ],
    targets: [
        .target(
            name: "RuuviNotifier",
            dependencies: [
                "RuuviOntology",
            ]),
        .target(
            name: "RuuviNotifierImpl",
            dependencies: [
                "RuuviNotifier",
                "RuuviOntology",
                "RuuviService",
                "RuuviNotification"
            ]),
        .testTarget(
            name: "RuuviNotifierTests",
            dependencies: ["RuuviNotifier"])
    ]
)
