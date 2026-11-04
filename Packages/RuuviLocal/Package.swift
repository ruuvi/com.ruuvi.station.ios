// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviLocal",
    platforms: [.iOS(.v16)],
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
        .package(path: "../RuuviOntology")
    ],
    targets: [
        .target(
            name: "RuuviLocal",
            dependencies: [
                "RuuviOntology"

            ]
        ),
        .target(
            name: "RuuviLocalUserDefaults",
            dependencies: [
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                "RuuviLocal",
            ]
        ),
        .testTarget(
            name: "RuuviLocalTests",
            dependencies: [
                .product(name: "RuuviOntology", package: "RuuviOntology"), "RuuviLocal", "RuuviLocalUserDefaults",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
