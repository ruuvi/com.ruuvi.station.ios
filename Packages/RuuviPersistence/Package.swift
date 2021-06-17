// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPersistence",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviPersistence",
            targets: ["RuuviPersistence"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviContext")
    ],
    targets: [
        .target(
            name: "RuuviPersistence",
            dependencies: [
                "RuuviOntology",
                "RuuviContext",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviPersistenceTests",
            dependencies: ["RuuviPersistence"])
    ]
)
