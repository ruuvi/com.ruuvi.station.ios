// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviContext",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviContext",
            targets: ["RuuviContext"]
        ),
        .library(
            name: "RuuviContextRealm",
            targets: ["RuuviContextRealm"]
        ),
        .library(
            name: "RuuviContextSQLite",
            targets: ["RuuviContextSQLite"]
        )
    ],
    dependencies: [
        .package(name: "Realm", url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.8.0")),
        .package(path: "../RuuviOntology"),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0"))
    ],
    targets: [
        .target(
            name: "RuuviContext",
            dependencies: [
                .product(name: "RealmSwift", package: "Realm"),
                .product(name: "GRDB", package: "GRDB")
            ]
        ),
        .target(
            name: "RuuviContextRealm",
            dependencies: [
                .product(name: "RealmSwift", package: "Realm"),
                "RuuviContext"
            ]
        ),
        .target(
            name: "RuuviContextSQLite",
            dependencies: [
                .product(name: "GRDB", package: "GRDB"),
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology"),
                "RuuviOntology",
                "RuuviContext"
            ]
        ),
        .testTarget(
            name: "RuuviContextTests",
            dependencies: ["RuuviContext"])
    ]
)
