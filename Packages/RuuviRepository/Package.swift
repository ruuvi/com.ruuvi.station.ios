// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviRepository",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviRepository",
            targets: ["RuuviRepository"]
        ),
        .library(
            name: "RuuviRepositoryCoordinator",
            targets: ["RuuviRepositoryCoordinator"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviContext"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviLocal"),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.12.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviStorage"),
    ],
    targets: [
        .target(
            name: "RuuviRepository",
            dependencies: [
                "RuuviOntology",
                "RuuviPool",
                "RuuviStorage",

            ]
        ),
        .target(
            name: "RuuviRepositoryCoordinator",
            dependencies: [
                "RuuviRepository",
                "RuuviOntology",
                "RuuviPool",
                "RuuviStorage",

            ]
        ),
        .testTarget(
            name: "RuuviRepositoryTests",
            dependencies: [
                "RuuviRepository", "RuuviRepositoryCoordinator",
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
                .product(name: "RuuviLocalUserDefaults", package: "RuuviLocal"),
                .product(name: "RuuviPoolCoordinator", package: "RuuviPool"),
                .product(name: "RuuviStorageCoordinator", package: "RuuviStorage"),
                .product(name: "GRDB", package: "GRDB"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
