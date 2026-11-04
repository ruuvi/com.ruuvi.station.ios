// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviMigration",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviMigration",
            targets: ["RuuviMigration"]
        ),
        .library(
            name: "RuuviMigrationImpl",
            targets: ["RuuviMigrationImpl"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviContext"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviService"),
    ],
    targets: [
        .target(
            name: "RuuviMigration",
            dependencies: []
        ),
        .target(
            name: "RuuviMigrationImpl",
            dependencies: [
                "RuuviOntology",
                "RuuviLocal",
                "RuuviPool",
                "RuuviContext",
                "RuuviStorage",
                "RuuviService",
                "RuuviMigration",
            ]
        ),
        .testTarget(
            name: "RuuviMigrationTests",
            dependencies: [
                "RuuviMigration", "RuuviMigrationImpl",
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
                .product(name: "RuuviStorageCoordinator", package: "RuuviStorage"),
                .product(name: "RuuviService", package: "RuuviService"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
