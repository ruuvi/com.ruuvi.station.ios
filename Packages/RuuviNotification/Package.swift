// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviNotification",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
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
        .package(url: "https://github.com/kean/Future", exact: "1.3.0"),
        .package(url: "https://github.com/rinat-enikeev/Humidity", from: "0.1.5"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviService"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviUser"),
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
                "Future",
                "RuuviService",
                "RuuviLocal",
                "RuuviStorage",
                "RuuviOntology",
                "RuuviCloud",
                "RuuviUser",
            ]
        ),
        .testTarget(
            name: "RuuviNotificationTests",
            dependencies: [
                "RuuviNotification", "RuuviNotificationLocal", "Future", "Humidity",
                "RuuviCloud", "RuuviOntology", "RuuviStorage",
            ]
        ),
    ]
)
