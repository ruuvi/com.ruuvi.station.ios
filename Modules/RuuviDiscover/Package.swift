// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviDiscover",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        .library(
            name: "RuuviDiscover",
            targets: ["RuuviDiscover"]
        ),
    ],
    dependencies: [
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
            name: "RuuviDiscoverTests"
        ),
    ]
)
