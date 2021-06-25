// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviAnalytics",
    products: [
        .library(
            name: "RuuviAnalytics",
            targets: ["RuuviAnalytics"])
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RuuviAnalytics",
            dependencies: []),
        .testTarget(
            name: "RuuviAnalyticsTests",
            dependencies: ["RuuviAnalytics"])
    ]
)
