// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviAnalytics",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviAnalytics",
            targets: ["RuuviAnalytics"]),
        .library(
            name: "RuuviAnalyticsImpl",
            targets: ["RuuviAnalyticsImpl"])
    ],
    dependencies: [
        .package(name: "Firebase", url: "https://github.com/firebase/firebase-ios-sdk", .upToNextMajor(from: "8.2.0")),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviVirtual"),
        .package(path: "../RuuviUser")
    ],
    targets: [
        .target(
            name: "RuuviAnalytics",
            dependencies: []),
        .target(
            name: "RuuviAnalyticsImpl",
            dependencies: [
                "RuuviAnalytics",
                .product(name: "FirebaseAnalytics", package: "Firebase"),
                "RuuviLocal",
                "RuuviStorage",
                "RuuviOntology",
                "RuuviVirtual",
                "RuuviUser"
            ]),
        .testTarget(
            name: "RuuviAnalyticsTests",
            dependencies: ["RuuviAnalytics"])
    ]
)
