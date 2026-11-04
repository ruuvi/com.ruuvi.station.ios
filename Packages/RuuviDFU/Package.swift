// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDFU",
    platforms: [.iOS(.v16)],
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
                .product(name: "NordicDFU", package: "IOS-Pods-DFU-Library"),
                .product(name: "iOSMcuManagerLibrary", package: "IOS-nRF-Connect-Device-Manager"),
            ]
        ),
        .target(
            name: "RuuviDFUImpl",
            dependencies: [
                "RuuviDFU",
                .product(name: "NordicDFU", package: "IOS-Pods-DFU-Library"),
                .product(name: "iOSMcuManagerLibrary", package: "IOS-nRF-Connect-Device-Manager"),
            ]
        ),
        .testTarget(
            name: "RuuviDFUTests",
            dependencies: ["RuuviDFU"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
