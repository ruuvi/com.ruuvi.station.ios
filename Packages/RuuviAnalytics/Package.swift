// swift-tools-version: 6.2
import PackageDescription

// Analytics implementations live in the application, which owns its Firebase dependency.
let package = Package(
    name: "RuuviAnalytics",
    platforms: [.iOS(.v16)],
    products: [.library(name: "RuuviAnalytics", targets: ["RuuviAnalytics"])],
    targets: [
        .target(name: "RuuviAnalytics"),
        .testTarget(name: "RuuviAnalyticsTests", dependencies: ["RuuviAnalytics"]),
    ],
    swiftLanguageModes: [.v5]
)
