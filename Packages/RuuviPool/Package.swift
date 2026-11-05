// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPool",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviPool",
            targets: ["RuuviPool"]
        ),
        .library(
            name: "RuuviPoolCoordinator",
            targets: ["RuuviPoolCoordinator"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviContext"),
    ],
    targets: [
        .target(
            name: "RuuviPool",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence",
                "RuuviLocal",

            ]
        ),
        .target(
            name: "RuuviPoolCoordinator",
            dependencies: [
                "RuuviPool",
                "RuuviOntology",
                "RuuviPersistence",
                "RuuviLocal",

            ]
        ),
        .testTarget(
            name: "RuuviPoolTests",
            dependencies: [
                "RuuviPool", "RuuviPoolCoordinator",
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviLocalUserDefaults", package: "RuuviLocal"),
                .product(name: "RuuviContext", package: "RuuviContext"),
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
