// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviRepository",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
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
            ]
        ),
        .target(
            name: "RuuviRepositoryCoordinator",
            dependencies: [
                "RuuviRepository",
                "RuuviOntology",
                "RuuviPool",
                "RuuviStorage",
            ]
        ),
        .testTarget(
            name: "RuuviRepositoryTests",
            dependencies: ["RuuviRepository"]
        ),
    ]
)
