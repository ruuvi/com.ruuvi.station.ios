// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviReactor",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviReactor",
            targets: ["RuuviReactor"])
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence")
    ],
    targets: [
        .target(
            name: "RuuviReactor",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence"
            ]
        ),
        .testTarget(
            name: "RuuviReactorTests",
            dependencies: ["RuuviReactor"])
    ]
)
