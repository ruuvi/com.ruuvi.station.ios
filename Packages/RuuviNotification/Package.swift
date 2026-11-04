// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviNotification",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "RuuviNotificationRemote", targets: ["RuuviNotificationRemote"]),
        .library(
            name: "RuuviNotification",
            targets: ["RuuviNotification"]
        ),
        .library(
            name: "RuuviNotificationLocal",
            targets: ["RuuviNotificationLocal"]
        ),
    ],
    dependencies: [
        .package(path: "../../Common/RuuviLocalization"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService"),
    ],
    targets: [
        .target(
            name: "RuuviNotificationRemote",
            dependencies: [.product(name: "RuuviLocalization", package: "RuuviLocalization")]
        ),
        .target(
            name: "RuuviNotification",
            dependencies: [
                .product(name: "RuuviOntology", package: "RuuviOntology")
            ]
        ),
        .target(
            name: "RuuviNotificationLocal",
            dependencies: [
                "RuuviNotification",
                "RuuviService",
                "RuuviLocal",
                "RuuviStorage",
                "RuuviOntology",
            ]
        ),
        .testTarget(
            name: "RuuviNotificationTests",
            dependencies: [
                "RuuviNotification", "RuuviNotificationLocal", "RuuviNotificationRemote", "RuuviLocalization",
                .product(name: "RuuviLocalUserDefaults", package: "RuuviLocal"),
                .product(name: "RuuviServiceAlert", package: "RuuviService"),
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
