// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RuuviFirmware",
    platforms: [.iOS(.v16)],
    products: [.library(name: "RuuviFirmware", targets: ["RuuviFirmware"])],
    dependencies: [
        .package(path: "../../Packages/RuuviOntology"),
        .package(path: "../../Packages/RuuviDaemon"),
        .package(path: "../../Packages/RuuviDFU"),
        .package(path: "../../Packages/RuuviCore"),
        .package(path: "../../Common/RuuviLocalization"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
    ],
    targets: [
        .target(
            name: "RuuviFirmware",
            dependencies: [
                .product(name: "RuuviCoreDiff", package: "RuuviCore"),
                "RuuviOntology", "RuuviDaemon", "RuuviDFU", "RuuviCore", "RuuviLocalization", "BTKit",
            ]),
        .testTarget(name: "RuuviFirmwareTests", dependencies: ["RuuviFirmware"]),
    ],
    swiftLanguageModes: [.v5]
)
