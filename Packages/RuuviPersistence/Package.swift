// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPersistence",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviPersistence",
            targets: ["RuuviPersistence"]),
        .library(
            name: "RuuviPersistenceRealm",
            targets: ["RuuviPersistenceRealm"]),
        .library(
            name: "RuuviPersistenceSQLite",
            targets: ["RuuviPersistenceSQLite"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(name: "Realm", url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.8.0")),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviContext")
    ],
    targets: [
        .target(
            name: "RuuviPersistence",
            dependencies: [
                "RuuviOntology",
                "RuuviContext",
                "Future"
            ]
        ),
        .target(
            name: "RuuviPersistenceRealm",
            dependencies: [
                .product(name: "RuuviContextRealm", package: "RuuviContext"),
                .product(name: "RuuviOntologyRealm", package: "RuuviOntology"),
                .product(name: "RealmSwift", package: "Realm"),
                "RuuviPersistence",
                "RuuviOntology",
                "RuuviContext",
                "Future"
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
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviPersistenceTests",
            dependencies: ["RuuviPersistence"])
    ]
)
