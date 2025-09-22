// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviReactor",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
    products: [
        .library(
            name: "RuuviReactor",
            targets: ["RuuviReactor"]
        ),
        .library(
            name: "RuuviReactorImpl",
            targets: ["RuuviReactorImpl"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviContext"),
    ],
    targets: [
        .target(
            name: "RuuviReactor",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence",
            ]
        ),
        .target(
            name: "RuuviReactorImpl",
            dependencies: [
                "RuuviReactor",
                "RuuviContext",
                "RuuviPersistence",
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology"),
            ]
        ),
        .testTarget(
            name: "RuuviReactorTests",
            dependencies: ["RuuviReactor"]
        ),
    ]
)
