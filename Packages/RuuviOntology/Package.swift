// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOntology",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviOntology",
            targets: ["RuuviOntology"]
        ),
        .library(
            name: "RuuviOntologySQLite",
            targets: ["RuuviOntologySQLite"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/rinat-enikeev/Humidity", from: "0.1.5"),
        .package(url: "https://github.com/ruuvi/BTKit", .upToNextMinor(from: "0.4.3")),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0")),
    ],
    targets: [
        .target(
            name: "RuuviOntology",
            dependencies: [
                "Humidity",
                "BTKit",
            ]
        ),
        .target(
            name: "RuuviOntologySQLite",
            dependencies: [
                "RuuviOntology",
                .product(name: "GRDB", package: "GRDB"),
            ]
        ),
        .testTarget(
            name: "RuuviOntologyTests",
            dependencies: ["RuuviOntology"]
        ),
    ]
)
