// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviPool",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviPool",
            targets: ["RuuviPool"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviLocal")
    ],
    targets: [
        .target(
            name: "RuuviPool",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence",
                "RuuviLocal",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviPoolTests",
            dependencies: ["RuuviPool"])
    ]
)
