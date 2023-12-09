// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDFU",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviDFU",
            targets: ["RuuviDFU"]
        ),
        .library(
            name: "RuuviDFUImpl",
            targets: ["RuuviDFUImpl"]
        ),
    ],
    dependencies: [
        .package(
            name: "NordicDFU",
            url: "https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library",
            from: "4.10.3"
        ),
    ],
    targets: [
        .target(
            name: "RuuviDFU",
            dependencies: [
                "NordicDFU",
            ]
        ),
        .target(
            name: "RuuviDFUImpl",
            dependencies: [
                "RuuviDFU",
                "NordicDFU",
            ]
        ),
        .testTarget(
            name: "RuuviDFUTests",
            dependencies: ["RuuviDFU"]
        ),
    ]
)
