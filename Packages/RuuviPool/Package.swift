// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPool",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
    products: [
        .library(
            name: "RuuviPool",
            targets: ["RuuviPool"]
        ),
        .library(
            name: "RuuviPoolCoordinator",
            targets: ["RuuviPoolCoordinator"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviLocal"),
    ],
    targets: [
        .target(
            name: "RuuviPool",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence",
                "RuuviLocal",
            ]
        ),
        .target(
            name: "RuuviPoolCoordinator",
            dependencies: [
                "RuuviPool",
                "RuuviOntology",
                "RuuviPersistence",
                "RuuviLocal",
            ]
        ),
        .testTarget(
            name: "RuuviPoolTests",
            dependencies: ["RuuviPool"]
        ),
    ]
)
