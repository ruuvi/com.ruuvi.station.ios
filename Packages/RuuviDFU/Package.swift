// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDFU",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
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
            url: "https://github.com/NordicSemiconductor/IOS-Pods-DFU-Library",
            from: "4.10.3"
        ),
        .package(
            url: "https://github.com/NordicSemiconductor/IOS-nRF-Connect-Device-Manager",
            from: "1.7.0"
        ),
    ],
    targets: [
        .target(
            name: "RuuviDFU",
            dependencies: [
                "NordicDFU",
                "iOSMcuManagerLibrary"
            ]
        ),
        .target(
            name: "RuuviDFUImpl",
            dependencies: [
                "RuuviDFU",
                "NordicDFU",
                "iOSMcuManagerLibrary",
            ]
        ),
        .testTarget(
            name: "RuuviDFUTests",
            dependencies: ["RuuviDFU"]
        ),
    ]
)
