// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviMigration",
    products: [
        .library(
            name: "RuuviMigration",
            targets: ["RuuviMigration"])
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RuuviMigration",
            dependencies: []),
        .testTarget(
            name: "RuuviMigrationTests",
            dependencies: ["RuuviMigration"])
    ]
)
