// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviContext",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviContext",
            targets: ["RuuviContext"]
        ),
        .library(
            name: "RuuviContextSQLite",
            targets: ["RuuviContextSQLite"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.12.0")),
    ],
    targets: [
        .target(
            name: "RuuviContext",
            dependencies: [
                .product(name: "GRDB", package: "GRDB")
            ]
        ),
        .target(
            name: "RuuviContextSQLite",
            dependencies: [
                .product(name: "GRDB", package: "GRDB"),
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology"),
                "RuuviOntology",
                "RuuviContext",
            ]
        ),
        .testTarget(
            name: "RuuviContextTests",
            dependencies: [
                "RuuviContextSQLite", "RuuviContext",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
