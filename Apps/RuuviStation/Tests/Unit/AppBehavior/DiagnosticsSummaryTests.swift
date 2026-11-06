import AVFoundation
import CoreLocation
import Photos
import UIKit
import UserNotifications
import XCTest
@testable import station

@MainActor final class DiagnosticsSummaryTests: XCTestCase {
    func testSupportSummaryIncludesAppDeviceAndPermissionsAndReturnsOnMainThread() async {
        let provider = InfoProviderImpl(
            appInfo: [
                "CFBundleDisplayName": "Ruuvi Station", "CFBundleShortVersionString": "3.1", "CFBundleVersion": "42",
            ],
            locationStatus: { .authorizedWhenInUse }, photoStatus: { .limited }, cameraStatus: { .denied },
            notificationStatus: { receive in DispatchQueue.global().async { receive(.provisional) } })
        let result = await withCheckedContinuation { continuation in
            provider.summary { summary in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(returning: summary)
            }
        }
        XCTAssertTrue(result.contains("Device: " + UIDevice.modelName + "\n"))
        XCTAssertTrue(
            result.contains("OS: " + UIDevice.current.systemName + " " + UIDevice.current.systemVersion + "\n"))
        XCTAssertTrue(result.contains("App: Ruuvi Station 3.1(42)\n"))
        XCTAssertTrue(result.contains("Location: when in use\n"))
        XCTAssertTrue(result.contains("Photo Library: limited\n"))
        XCTAssertTrue(result.contains("Camera: denied\n"))
        XCTAssertTrue(result.contains("Notifications: provisional\n"))
    }

    func testSupportSummaryDistinguishesEachPermissionState() async {
        for (status, expected): (CLAuthorizationStatus, String) in [
            (.authorizedAlways, "always"), (.authorizedWhenInUse, "when in use"), (.denied, "denied"),
            (.notDetermined, "not determined"), (.restricted, "restricted"),
        ] {
            XCTAssertEqual(InfoProviderImpl(locationStatus: { status }).locationPermission, "Location: " + expected)
        }
        for (status, expected): (PHAuthorizationStatus, String) in [
            (.authorized, "authorized"), (.denied, "denied"), (.notDetermined, "not determined"),
            (.restricted, "restricted"), (.limited, "limited"),
        ] {
            XCTAssertEqual(
                InfoProviderImpl(photoStatus: { status }).photoLibraryPermission, "Photo Library: " + expected)
        }
        for (status, expected): (AVAuthorizationStatus, String) in [
            (.authorized, "authorized"), (.denied, "denied"), (.notDetermined, "not determined"),
            (.restricted, "restricted"),
        ] {
            XCTAssertEqual(InfoProviderImpl(cameraStatus: { status }).cameraPermission, "Camera: " + expected)
        }
        for (status, expected): (UNAuthorizationStatus, String) in [
            (.authorized, "authorized"), (.denied, "denied"), (.notDetermined, "notDetermined"),
            (.provisional, "provisional"), (.ephemeral, "ephemeral"),
        ] {
            let provider = InfoProviderImpl(notificationStatus: { $0(status) })
            let result = await withCheckedContinuation { continuation in
                provider.summary { continuation.resume(returning: $0) }
            }
            XCTAssertTrue(result.contains("Notifications: " + expected + "\n"))
        }
    }

    func testMissingBundleMetadataProducesReadableFallbacks() {
        let provider = InfoProviderImpl(appInfo: [:])
        XCTAssertEqual(provider.appName, "unknown")
        XCTAssertEqual(provider.appVersion, "unknown(unknown)")
        let partial = InfoProviderImpl(appInfo: ["CFBundleShortVersionString": "3.1"])
        XCTAssertEqual(partial.appVersion, "3.1(unknown)")
    }
}
