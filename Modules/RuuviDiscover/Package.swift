// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDiscover",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "RuuviDiscover",
            targets: ["RuuviDiscover"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/RuuviDaemon"),
        .package(path: "../../Packages/RuuviDFU"),
        .package(path: "../../Packages/RuuviCore"),
        .package(path: "../RuuviFirmware"),
        .package(path: "../../Packages/RuuviOntology"),
        .package(path: "../../Packages/RuuviContext"),
        .package(path: "../../Packages/RuuviReactor"),
        .package(path: "../../Packages/RuuviLocal"),
        .package(path: "../../Packages/RuuviService"),
        .package(path: "../../Common/RuuviPresenters"),
        .package(path: "../../Common/RuuviLocalization"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
    ],
    targets: [
        .target(
            name: "RuuviDiscover",
            dependencies: [
                .product(name: "RuuviCore", package: "RuuviCore"),
                .product(name: "RuuviDFU", package: "RuuviDFU"),
                .product(name: "RuuviDaemon", package: "RuuviDaemon"),
                .product(name: "RuuviFirmware", package: "RuuviFirmware"),
                "RuuviOntology",
                "RuuviContext",
                "RuuviReactor",
                "RuuviLocal",
                "RuuviService",
                "RuuviPresenters",
                "BTKit",
                "RuuviLocalization",
            ]
        ),
        .testTarget(
            name: "RuuviDiscoverTests",
            dependencies: ["RuuviDiscover", "RuuviOntology"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
