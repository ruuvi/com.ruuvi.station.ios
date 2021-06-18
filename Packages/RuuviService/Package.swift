// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviService",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviService",
            targets: ["RuuviService"]),
        .library(
            name: "RuuviServiceAlert",
            targets: ["RuuviServiceAlert"]),
        .library(
            name: "RuuviServiceAppSettings",
            targets: ["RuuviServiceAppSettings"]),
        .library(
            name: "RuuviServiceCloudSync",
            targets: ["RuuviServiceCloudSync"]),
        .library(
            name: "RuuviServiceOffsetCalibration",
            targets: ["RuuviServiceOffsetCalibration"]),
        .library(
            name: "RuuviServiceOwnership",
            targets: ["RuuviServiceOwnership"]),
        .library(
            name: "RuuviServiceSensorProperties",
            targets: ["RuuviServiceSensorProperties"]),
        .library(
            name: "RuuviServiceSensorRecords",
            targets: ["RuuviServiceSensorRecords"]),
        .library(
            name: "RuuviServiceFactory",
            targets: ["RuuviServiceFactory"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviRepository"),
        .package(path: "../RuuviCore")
    ],
    targets: [
        .target(
            name: "RuuviService",
            dependencies: [
                "Future",
                "RuuviOntology",
                "RuuviStorage",
                "RuuviCloud",
                "RuuviPool",
                "RuuviLocal",
                "RuuviRepository",
                "RuuviCore"
            ]
        ),
        .target(
            name: "RuuviServiceAlert",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceAppSettings",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceCloudSync",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceOffsetCalibration",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceOwnership",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceSensorProperties",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceSensorRecords",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceFactory",
            dependencies: [
                "RuuviService",
                "RuuviServiceAlert",
                "RuuviServiceAppSettings",
                "RuuviServiceCloudSync",
                "RuuviServiceOffsetCalibration",
                "RuuviServiceOwnership",
                "RuuviServiceSensorProperties",
                "RuuviServiceSensorRecords"
            ]
        ),
        .testTarget(
            name: "RuuviServiceTests",
            dependencies: ["RuuviService"])
    ]
)
