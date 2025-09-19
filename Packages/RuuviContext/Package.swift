// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviContext",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
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
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0")),
    ],
    targets: [
        .target(
            name: "RuuviContext",
            dependencies: [
                .product(name: "GRDB", package: "GRDB"),
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
            dependencies: ["RuuviContext"]
        ),
    ]
)
