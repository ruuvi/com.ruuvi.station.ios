// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviLocal",
    platforms: [.macOS(.v10_15), .iOS(.v16)],
    products: [
        .library(
            name: "RuuviLocal",
            targets: ["RuuviLocal"]
        ),
        .library(
            name: "RuuviLocalUserDefaults",
            targets: ["RuuviLocalUserDefaults"]
        ),
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
    ],
    targets: [
        .target(
            name: "RuuviLocal",
            dependencies: [
                "RuuviOntology",
            ]
        ),
        .target(
            name: "RuuviLocalUserDefaults",
            dependencies: [
                "RuuviLocal"
            ]
        ),
        .testTarget(
            name: "RuuviLocalTests",
            dependencies: ["RuuviLocal"]
        ),
    ]
)
