// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviMigration",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
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
                .product(name: "RuuviOntologyRealm", package: "RuuviOntology"),
            ]
        ),
        .testTarget(
            name: "RuuviMigrationTests",
            dependencies: ["RuuviMigration"]
        ),
    ]
)
