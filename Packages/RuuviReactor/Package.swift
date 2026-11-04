// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviReactor",
    platforms: [.iOS(.v16)],
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
        .package(path: "../RuuviAnalytics"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviContext"),
    ],
    targets: [
        .target(
            name: "RuuviReactor",
            dependencies: [
                .product(name: "RuuviAnalytics", package: "RuuviAnalytics"),
                .product(name: "RuuviContext", package: "RuuviContext"),
                "RuuviOntology",
                "RuuviPersistence",
            ]
        ),
        .target(
            name: "RuuviReactorImpl",
            dependencies: [
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviAnalytics", package: "RuuviAnalytics"),
                "RuuviReactor",
                "RuuviContext",
                "RuuviPersistence",
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology"),
            ]
        ),
        .testTarget(
            name: "RuuviReactorTests",
            dependencies: [
                .product(name: "RuuviAnalytics", package: "RuuviAnalytics"),
                .product(name: "RuuviContext", package: "RuuviContext"),
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPersistence", package: "RuuviPersistence"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
                "RuuviReactorImpl", "RuuviReactor",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
