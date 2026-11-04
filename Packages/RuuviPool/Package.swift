// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPool",
    platforms: [.iOS(.v16)],
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
    ],
    swiftLanguageModes: [.v5]
)
