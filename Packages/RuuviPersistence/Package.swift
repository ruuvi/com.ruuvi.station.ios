// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPersistence",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        .library(
            name: "RuuviPersistence",
            targets: ["RuuviPersistence"]
        ),
        .library(
            name: "RuuviPersistenceSQLite",
            targets: ["RuuviPersistenceSQLite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviContext"),
    ],
    targets: [
        .target(
            name: "RuuviPersistence",
            dependencies: [
                "RuuviOntology",
                "RuuviContext",
                "Future",
            ]
        ),
        .target(
            name: "RuuviPersistenceSQLite",
            dependencies: [
                .product(name: "GRDB", package: "GRDB"),
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology"),
                "RuuviPersistence",
                "RuuviOntology",
                "RuuviContext",
                "Future",
            ]
        ),
        .testTarget(
            name: "RuuviPersistenceTests",
            dependencies: ["RuuviPersistence"]
        ),
    ]
)
