// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOntology",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviOntology",
            targets: ["RuuviOntology"]
        ),
        .library(
            name: "RuuviOntologyRealm",
            targets: ["RuuviOntologyRealm"]
        ),
        .library(
            name: "RuuviOntologySQLite",
            targets: ["RuuviOntologySQLite"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/rinat-enikeev/Humidity", from: "0.1.5"),
        .package(url: "https://github.com/rinat-enikeev/BTKit", .upToNextMinor(from: "0.3.0")),
        .package(name: "Realm", url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.8.0")),
        .package(name: "GRDB", url: "https://github.com/groue/GRDB.swift", .upToNextMajor(from: "4.14.0"))
    ],
    targets: [
        .target(
            name: "RuuviOntology",
            dependencies: [
                "Humidity",
                "BTKit"
            ]),
        .target(
            name: "RuuviOntologyRealm",
            dependencies: [
                "RuuviOntology",
                .product(name: "RealmSwift", package: "Realm")
            ]),
        .target(
            name: "RuuviOntologySQLite",
            dependencies: [
                "RuuviOntology",
                .product(name: "GRDB", package: "GRDB")
            ]),
        .testTarget(
            name: "RuuviOntologyTests",
            dependencies: ["RuuviOntology"])
    ]
)
