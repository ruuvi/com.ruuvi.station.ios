// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviNotification",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
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
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService"),
    ],
    targets: [
        .target(
            name: "RuuviNotification",
            dependencies: []
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
            dependencies: ["RuuviNotification"]
        ),
    ]
)
