// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviStorage",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
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
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
    ],
    targets: [
        .target(
            name: "RuuviStorage",
            dependencies: [
                "Future",
                "RuuviOntology",
                "RuuviPersistence",
            ]
        ),
        .target(
            name: "RuuviStorageCoordinator",
            dependencies: [
                "RuuviStorage",
                "Future",
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
