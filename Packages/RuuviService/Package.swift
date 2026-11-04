// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviService",
    platforms: [.iOS(.v16)],
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
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0"),
        .package(path: "../RuuviUser"),
        .package(url: "https://github.com/rinat-enikeev/Humidity", from: "0.1.5"),
        .package(url: "https://github.com/ruuvi/BTKit", branch: "master"),
        .package(url: "https://github.com/jmcnamara/libxlsxwriter", exact: "1.2.4"),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviStorage"),
        .package(path: "../../Common/RuuviLocalization"),
        .package(path: "../RuuviCloud"),
        .package(path: "../RuuviPool"),
        .package(path: "../RuuviLocal"),
        .package(path: "../RuuviRepository"),
        .package(path: "../RuuviCore"),
        .package(path: "../RuuviContext"),
        .package(path: "../RuuviPersistence"),
    ],
    targets: [
        .target(
            name: "RuuviService",
            dependencies: [
                "RuuviLocalization",

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
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                "RuuviService",
                "RuuviLocalization",
            ]
        ),
        .target(
            name: "RuuviServiceAuth",
            dependencies: [
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                .product(name: "RuuviUser", package: "RuuviUser"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceCloudNotification",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviCore", package: "RuuviCore"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                .product(name: "RuuviUser", package: "RuuviUser"),
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
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                "RuuviService",
                "RuuviStorage",
            ]
        ),
        .target(
            name: "RuuviServiceCloudSync",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviRepository", package: "RuuviRepository"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceOffsetCalibration",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceOwnership",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                .product(name: "RuuviUser", package: "RuuviUser"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceSensorProperties",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviCore", package: "RuuviCore"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
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
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceExport",
            dependencies: [
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviLocalization", package: "RuuviLocalization"),
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                .product(name: "libxlsxwriter", package: "libxlsxwriter"),
                "RuuviService",
            ]
        ),
        .target(
            name: "RuuviServiceGATT",
            dependencies: [
                .product(name: "RuuviOntology", package: "RuuviOntology"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                "RuuviService",
                "BTKit",
            ]
        ),
        .target(
            name: "RuuviServiceMeasurement",
            dependencies: [
                .product(name: "RuuviLocalization", package: "RuuviLocalization"),
                "RuuviService",
                "RuuviLocal",
                "RuuviOntology",
                "Humidity",
            ]
        ),
        .target(
            name: "RuuviServiceFactory",
            dependencies: [
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                .product(name: "RuuviCore", package: "RuuviCore"),
                .product(name: "RuuviLocal", package: "RuuviLocal"),
                .product(name: "RuuviPool", package: "RuuviPool"),
                .product(name: "RuuviRepository", package: "RuuviRepository"),
                .product(name: "RuuviStorage", package: "RuuviStorage"),
                .product(name: "RuuviUser", package: "RuuviUser"),
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
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "RuuviRepositoryCoordinator", package: "RuuviRepository"),
                "RuuviServiceExport", "RuuviServiceMeasurement",
                "RuuviServiceOwnership",
                "RuuviServiceSensorProperties",
                .product(name: "RuuviPoolCoordinator", package: "RuuviPool"),
                .product(name: "RuuviCloud", package: "RuuviCloud"),
                "RuuviServiceAppSettings",
                "RuuviServiceGATT",
                "RuuviServiceCloudSync",
                "RuuviServiceAlert",
                .product(name: "RuuviContextSQLite", package: "RuuviContext"),
                .product(name: "RuuviPersistenceSQLite", package: "RuuviPersistence"),
                .product(name: "RuuviLocalUserDefaults", package: "RuuviLocal"),
                .product(name: "RuuviStorageCoordinator", package: "RuuviStorage"),
                "RuuviService",
                "RuuviOntology",
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
