// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviCloud",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviCloud",
            targets: ["RuuviCloud"]
        ),
        .library(
            name: "RuuviCloudApi",
            targets: ["RuuviCloudApi"]
        ),
        .library(
            name: "RuuviCloudPure",
            targets: ["RuuviCloudPure"]
        ),
    ],
    dependencies: [
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.12.0")),
        .package(path: "../RuuviContext"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviStorage"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviUser"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviLocal"),
    ],
    targets: [
        .target(
            name: "RuuviCloud",
            dependencies: [

                "RuuviOntology",
                "RuuviPool",
                "RuuviLocal",
                "RuuviUser",
            ]
        ),
        .target(
            name: "RuuviCloudApi",
            dependencies: [
                "RuuviCloud",
                "RuuviOntology",

                "BTKit",
            ]
        ),
        .target(
            name: "RuuviCloudPure",
            dependencies: [
                .product(name: "RuuviPool", package: "RuuviPool"),
                "RuuviCloud",
                "RuuviCloudApi",
                "RuuviOntology",
                "RuuviUser",

            ]
        ),
        .testTarget(
            name: "RuuviCloudTests",
            dependencies: [
                "RuuviCloud", "RuuviCloudApi", "RuuviCloudPure",
                .product(name: "GRDB", package: "GRDB"),
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
                .product(name: "RuuviPoolCoordinator", package: "RuuviPool"),
                .product(name: "RuuviStorageCoordinator", package: "RuuviStorage"),
                .product(name: "RuuviLocalUserDefaults", package: "RuuviLocal"),
                .product(name: "RuuviUser", package: "RuuviUser"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
