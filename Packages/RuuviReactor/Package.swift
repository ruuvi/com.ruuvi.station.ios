// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RuuviReactor",
    platforms: [.macOS(.v10_15), .iOS(.v11)],
    products: [
        .library(
            name: "RuuviReactor",
            targets: ["RuuviReactor"]),
        .library(
            name: "RuuviReactorImpl",
            targets: ["RuuviReactorImpl"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift", .upToNextMinor(from: "6.2.0")),
        .package(path: "../RuuviOntology"),
        .package(path: "../RuuviPersistence"),
        .package(path: "../RuuviContext")
    ],
    targets: [
        .target(
            name: "RuuviReactor",
            dependencies: [
                "RuuviOntology",
                "RuuviPersistence"
            ]
        ),
        .target(
            name: "RuuviReactorImpl",
            dependencies: [
                "RxSwift",
                "RuuviReactor",
                "RuuviContext",
                "RuuviPersistence",
                .product(name: "RuuviOntologyRealm", package: "RuuviOntology"),
                .product(name: "RuuviOntologySQLite", package: "RuuviOntology")
            ]
        ),
        .testTarget(
            name: "RuuviReactorTests",
            dependencies: ["RuuviReactor"])
    ]
)
