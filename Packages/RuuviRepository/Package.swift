// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviRepository",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviRepository",
            targets: ["RuuviRepository"]
        ),
        .library(
            name: "RuuviRepositoryCoordinator",
            targets: ["RuuviRepositoryCoordinator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviStorage"),
    ],
    targets: [
        .target(
            name: "RuuviRepository",
            dependencies: [
                "RuuviOntology",
                "RuuviPool",
                "RuuviStorage",
                "Future",
            ]
        ),
        .target(
            name: "RuuviRepositoryCoordinator",
            dependencies: [
                "RuuviRepository",
                "RuuviOntology",
                "RuuviPool",
                "RuuviStorage",
                "Future",
            ]
        ),
        .testTarget(
            name: "RuuviRepositoryTests",
            dependencies: ["RuuviRepository"]
        ),
    ]
)
