// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOntology",
    platforms: [.iOS(.v16)],
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
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "7.12.0")),
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
    ],
    swiftLanguageModes: [.v5]
)
