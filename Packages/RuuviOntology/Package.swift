// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviOntology",
    platforms: [.macOS(.v10_15), .iOS(.v10)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "RuuviOntology",
            targets: ["RuuviOntology"])
    ],
    dependencies: [
        .package(url: "https://github.com/rinat-enikeev/Humidity.git", from: "0.1.5")
    ],
    targets: [
        .target(
            name: "RuuviOntology",
            dependencies: [
                "Humidity"
            ]),
        .testTarget(
            name: "RuuviOntologyTests",
            dependencies: ["RuuviOntology"])
    ]
)
