// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviVirtual",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviVirtual",
            targets: ["RuuviVirtual"])
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(url: "https://github.com/kean/Future", .exact("1.3.0"))
    ],
    targets: [
        .target(
            name: "RuuviVirtual",
            dependencies: [
                "RuuviOntology",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviVirtualTests",
            dependencies: ["RuuviVirtual"])
    ]
)
