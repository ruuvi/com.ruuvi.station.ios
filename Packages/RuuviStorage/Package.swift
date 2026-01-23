// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviStorage",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        .library(
            name: "RuuviStorage",
            targets: ["RuuviStorage"]
        ),
        .library(
            name: "RuuviStorageCoordinator",
            targets: ["RuuviStorageCoordinator"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
    ],
    targets: [
        .target(
            name: "RuuviStorage",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence",
            ]
        ),
        .target(
            name: "RuuviStorageCoordinator",
            dependencies: [
                "RuuviStorage",
                "RuuviOntology",
                "RuuviPersistence",
            ]
        ),
        .testTarget(
            name: "RuuviStorageTests",
            dependencies: ["RuuviStorage"]
        ),
    ]
)
