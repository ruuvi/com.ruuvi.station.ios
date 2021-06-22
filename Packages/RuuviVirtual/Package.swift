// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviVirtual",
    platforms: [.macOS(.v10_15), .iOS(.v13)],
    products: [
        .library(
            name: "RuuviVirtual",
            targets: ["RuuviVirtual"]
        ),
        .library(
            name: "RuuviVirtualModel",
            targets: ["RuuviVirtualModel"]
        ),
        .library(
            name: "RuuviVirtualOWM",
            targets: ["RuuviVirtualOWM"]
        ),
        .library(
            name: "RuuviVirtualPersistence",
            targets: ["RuuviVirtualPersistence"]
        ),
        .library(
            name: "RuuviVirtualReactor",
            targets: ["RuuviVirtualReactor"]
        ),
        .library(
            name: "RuuviVirtualRepository",
            targets: ["RuuviVirtualRepository"]
        ),
        .library(
            name: "RuuviVirtualService",
            targets: ["RuuviVirtualService"]
        ),
        .library(
            name: "RuuviVirtualStorage",
            targets: ["RuuviVirtualStorage"]
        )
    ],
    dependencies: [
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviCore"),
        .package(path: "../RuuviLocation"),
        .package(path: "../RuuviContext"),
        .package(path: "../RuuviLocal"),
        .package(url: "https://github.com/kean/Future", .exact("1.3.0")),
        .package(name: "Realm", url: "https://github.com/realm/realm-cocoa", .upToNextMajor(from: "10.8.0"))
    ],
    targets: [
        .target(
            name: "RuuviVirtual",
            dependencies: [
                "RuuviOntology",
                "RuuviCore",
                "RuuviLocation",
                "Future"
            ]
        ),
        .target(
            name: "RuuviVirtualModel",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "Future",
                .product(name: "RealmSwift", package: "Realm")
            ]
        ),
        .target(
            name: "RuuviVirtualOWM",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "Future"
            ]
        ),
        .target(
            name: "RuuviVirtualPersistence",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "RuuviContext",
                "RuuviLocal",
                "Future",
                "RuuviVirtualModel",
                .product(name: "RealmSwift", package: "Realm")
            ]
        ),
        .target(
            name: "RuuviVirtualReactor",
            dependencies: [
                "RuuviOntology",
                "RuuviContext",
                "RuuviVirtual",
                "RuuviVirtualModel",
                "Future",
                .product(name: "RealmSwift", package: "Realm")
            ]
        ),
        .target(
            name: "RuuviVirtualRepository",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "Future"
            ]
        ),
        .target(
            name: "RuuviVirtualService",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "RuuviLocation",
                "RuuviLocal",
                "RuuviCore",
                "Future"
            ]
        ),
        .target(
            name: "RuuviVirtualStorage",
            dependencies: [
                "RuuviOntology",
                "RuuviVirtual",
                "Future"
            ]
        ),
        .testTarget(
            name: "RuuviVirtualTests",
            dependencies: ["RuuviVirtual"])
    ]
)
