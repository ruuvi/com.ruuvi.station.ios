// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviService",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        .library(
            name: "RuuviService",
            targets: ["RuuviService"]
        ),
        .library(
            name: "RuuviServiceAlert",
            targets: ["RuuviServiceAlert"]
        ),
        .library(
            name: "RuuviServiceAuth",
            targets: ["RuuviServiceAuth"]
        ),
        .library(
            name: "RuuviServiceCloudNotification",
            targets: ["RuuviServiceCloudNotification"]
        ),
        .library(
            name: "RuuviServiceAppSettings",
            targets: ["RuuviServiceAppSettings"]
        ),
        .library(
            name: "RuuviServiceCloudSync",
            targets: ["RuuviServiceCloudSync"]
        ),
        .library(
            name: "RuuviServiceOffsetCalibration",
            targets: ["RuuviServiceOffsetCalibration"]
        ),
        .library(
            name: "RuuviServiceOwnership",
            targets: ["RuuviServiceOwnership"]
        ),
        .library(
            name: "RuuviServiceSensorProperties",
            targets: ["RuuviServiceSensorProperties"]
        ),
        .library(
            name: "RuuviServiceSensorRecords",
            targets: ["RuuviServiceSensorRecords"]
        ),
        .library(
            name: "RuuviServiceMeasurement",
            targets: ["RuuviServiceMeasurement"]
        ),
        .library(
            name: "RuuviServiceExport",
            targets: ["RuuviServiceExport"]
        ),
        .library(
            name: "RuuviServiceGATT",
            targets: ["RuuviServiceGATT"]
        ),
        .library(
            name: "RuuviServiceFactory",
            targets: ["RuuviServiceFactory"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(url: "https://github.com/rinat-enikeev/Humidity", from: "0.1.5"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
        .package(url: "https://github.com/ruuvi/xlsxwriter.swift", branch: "SPM"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviRepository"),
        .package(path: "../RuuviCore"),
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
                "RuuviCore",
            ]
        ),
        .target(
            name: "RuuviServiceAlert",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceAuth",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceCloudNotification",
            dependencies: [
                "RuuviService",
                .product(
                    name: "RuuviCloudApi",
                    package: "RuuviCloud"
                ),
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
                "RuuviService",
                .product(
                    name: "RuuviCloudApi",
                    package: "RuuviCloud"
                ),
            ]
        ),
        .target(
            name: "RuuviServiceSensorRecords",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceExport",
            dependencies: [
                "RuuviService"
            ]
        ),
        .target(
            name: "RuuviServiceGATT",
            dependencies: [
                "RuuviService",
                "BTKit",
            ]
        ),
        .target(
            name: "RuuviServiceMeasurement",
            dependencies: [
                "RuuviService",
                "RuuviLocal",
                "RuuviOntology",
                "Humidity",
            ]
        ),
        .target(
            name: "RuuviServiceFactory",
            dependencies: [
                "RuuviService",
                "RuuviServiceAuth",
                "RuuviServiceAlert",
                "RuuviServiceAppSettings",
                "RuuviServiceCloudSync",
                "RuuviServiceOffsetCalibration",
                "RuuviServiceOwnership",
                "RuuviServiceSensorProperties",
                "RuuviServiceSensorRecords",
                "RuuviServiceCloudNotification",
            ]
        ),
        .testTarget(
            name: "RuuviServiceTests",
            dependencies: ["RuuviService"]
        ),
    ]
)
