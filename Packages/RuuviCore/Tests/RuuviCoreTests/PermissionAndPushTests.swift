import AVFoundation
import CoreLocation
import Photos
@testable import RuuviCore
#if SWIFT_PACKAGE
    @testable import RuuviCoreDiff
    @testable import RuuviCorePermission
    @testable import RuuviCorePN
#endif
import UserNotifications
import XCTest

@MainActor final class PermissionAndPushTests: XCTestCase {
    func testPhotoPermissionsPreserveLimitedAccessAndDeliverResultsOnMainThread() async {
        for status: PHAuthorizationStatus in [.notDetermined, .restricted, .denied, .authorized, .limited] {
            var requests = 0
            let permission = RuuviCorePermissionImpl(
                locationManager: PermissionLocation(),
                access: PermissionAccess(
                    photoStatus: { status },
                    requestPhoto: { callback in
                        requests += 1
                        DispatchQueue.global().async { callback(status) }
                    },
                    cameraStatus: { .denied }, requestCamera: { $0(false) }))
            XCTAssertEqual(permission.photoLibraryAuthorizationStatus, status)
            let allowed = status == .authorized || status == .limited
            XCTAssertEqual(permission.isPhotoLibraryPermissionGranted, allowed)
            let completion = expectation(description: "Photo permission result")
            permission.requestPhotoLibraryPermission {
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual($0, allowed)
                completion.fulfill()
            }
            await fulfillment(of: [completion], timeout: 2)
            XCTAssertEqual(requests, 1)
            permission.requestPhotoLibraryPermission(completion: nil)
            XCTAssertEqual(requests, 2)
        }
    }

    func testCameraPermissionsAndLocationForwardingRespectEveryAuthorizationState() async {
        let location = PermissionLocation()
        for status: AVAuthorizationStatus in [.notDetermined, .restricted, .denied, .authorized] {
            let allowed = status == .authorized
            let permission = RuuviCorePermissionImpl(
                locationManager: location,
                access: PermissionAccess(
                    photoStatus: { .denied }, requestPhoto: { $0(.denied) },
                    cameraStatus: { status },
                    requestCamera: { callback in
                        DispatchQueue.global().async { callback(allowed) }
                    }))
            XCTAssertEqual(permission.cameraAuthorizationStatus, status)
            XCTAssertEqual(permission.isCameraPermissionGranted, allowed)
            let completion = expectation(description: "Camera permission result")
            permission.requestCameraPermission {
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual($0, allowed)
                completion.fulfill()
            }
            await fulfillment(of: [completion], timeout: 2)
            permission.requestCameraPermission(completion: nil)
            for locationStatus: CLAuthorizationStatus in [
                .notDetermined, .denied, .restricted, .authorizedAlways, .authorizedWhenInUse,
            ] {
                location.locationAuthorizationStatus = locationStatus
                XCTAssertEqual(permission.locationAuthorizationStatus, locationStatus)
                XCTAssertEqual(permission.isLocationPermissionGranted, location.isLocationPermissionGranted)
                let completed = expectation(description: "Location permission result")
                permission.requestLocationPermission {
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertEqual($0, location.isLocationPermissionGranted)
                    completed.fulfill()
                }
                await fulfillment(of: [completed], timeout: 2)
            }
            permission.requestLocationPermission(completion: nil)
        }
    }

    func testDefaultPermissionAdapterReadsCurrentSystemStatusWithoutPrompting() {
        let permission = RuuviCorePermissionImpl(locationManager: PermissionLocation())
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        XCTAssertEqual(permission.photoLibraryAuthorizationStatus, photoStatus)
        XCTAssertEqual(
            permission.isPhotoLibraryPermissionGranted, photoStatus == .authorized || photoStatus == .limited)
        XCTAssertEqual(permission.cameraAuthorizationStatus, AVCaptureDevice.authorizationStatus(for: .video))
        XCTAssertEqual(
            permission.isCameraPermissionGranted, AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
    }

    func testPushStorageDistinguishesMissingTokenIDFromZeroAndRoundTripsAllFields() throws {
        let name = "ruuvi-core-push-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let push = RuuviCorePNImpl(defaults: defaults, access: notificationAccess())
        XCTAssertNil(push.pnTokenData)
        XCTAssertNil(push.fcmToken)
        XCTAssertNil(push.fcmTokenId)
        XCTAssertNil(push.fcmTokenLastRefreshed)
        push.pnTokenData = Data([0, 1, 127, 255])
        push.fcmToken = "token/value"
        push.fcmTokenId = 42
        push.fcmTokenLastRefreshed = Date(timeIntervalSince1970: 123)
        let restored = RuuviCorePNImpl(defaults: defaults, access: notificationAccess())
        XCTAssertEqual(restored.pnTokenData, Data([0, 1, 127, 255]))
        XCTAssertEqual(restored.fcmToken, "token/value")
        XCTAssertEqual(restored.fcmTokenId, 42)
        XCTAssertEqual(restored.fcmTokenLastRefreshed, Date(timeIntervalSince1970: 123))
        restored.fcmTokenId = 0
        XCTAssertEqual(restored.fcmTokenId, 0)
        restored.pnTokenData = nil
        restored.fcmToken = nil
        restored.fcmTokenId = nil
        restored.fcmTokenLastRefreshed = nil
        XCTAssertNil(push.pnTokenData)
        XCTAssertNil(push.fcmToken)
        XCTAssertNil(push.fcmTokenId)
        XCTAssertNil(push.fcmTokenLastRefreshed)
    }

    func testPushAuthorizationIncludesProvisionalAndEphemeralAccessAndUsesMainThread() async {
        for (system, expected): (UNAuthorizationStatus, PNAuthorizationStatus) in [
            (.notDetermined, .notDetermined), (.denied, .denied), (.authorized, .authorized),
            (.provisional, .authorized), (.ephemeral, .authorized),
        ] {
            let push = RuuviCorePNImpl(
                defaults: .standard,
                access: NotificationAccess(
                    status: { callback in DispatchQueue.global().async { callback(system) } },
                    request: { _, _ in XCTFail("Reading permission must not prompt") },
                    register: { XCTFail("Reading permission must not register") }))
            let completion = expectation(description: "Notification permission result")
            push.getRemoteNotificationsAuthorizationStatus {
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual($0, expected)
                completion.fulfill()
            }
            await fulfillment(of: [completion], timeout: 2)
        }
    }

    func testPushRegistrationRequestsAllOptionsAndRegistersOnlyAfterAnErrorFreeResponse() async {
        for granted in [false, true] {
            var callback: ((Bool, Error?) -> Void)?
            var registrations = 0
            let registered = expectation(description: "APNs registration")
            let push = RuuviCorePNImpl(
                defaults: .standard,
                access: NotificationAccess(
                    status: { _ in XCTFail("Registration does not read settings first") },
                    request: { options, completion in
                        XCTAssertEqual(options, [.sound, .alert, .badge])
                        callback = completion
                    },
                    register: {
                        XCTAssertTrue(Thread.isMainThread)
                        registrations += 1
                        registered.fulfill()
                    }))
            push.registerForRemoteNotifications()
            XCTAssertEqual(registrations, 0)
            callback?(granted, nil)
            await fulfillment(of: [registered], timeout: 2)
            XCTAssertEqual(registrations, 1)
        }
        let failed = RuuviCorePNImpl(
            defaults: .standard,
            access: NotificationAccess(
                status: { _ in }, request: { _, callback in callback(false, URLError(.unknown)) },
                register: { XCTFail("A failed authorization request cannot register") }))
        failed.registerForRemoteNotifications()
        await Task.yield()
    }

    func testReloadableLookupUsesStoredIndicesRatherThanArrayPositionsAndReturnsNilForMissingKeys() {
        let cells = ReloadableCellData(items: [
            ReloadableCell(key: "first", value: 1, index: 7), .init(key: "second", value: 2, index: 3),
        ])
        XCTAssertEqual(cells[7]?.value, 1)
        XCTAssertEqual(cells["second"]?.value, 2)
        XCTAssertNil(cells[0])
        XCTAssertNil(cells["missing"])
        let sections = ReloadableSectionData(items: [
            ReloadableSection(key: "section", value: cells.items, index: 4)
        ])
        XCTAssertEqual(sections[4]?.key, "section")
        XCTAssertEqual(sections["section"]?.value.count, 2)
        XCTAssertNil(sections[0])
        XCTAssertNil(sections["missing"])
    }

    private func notificationAccess() -> NotificationAccess {
        .init(status: { _ in }, request: { _, _ in }, register: {})
    }
}

@MainActor private final class PermissionLocation: RuuviCoreLocation {
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLocationPermissionGranted: Bool {
        locationAuthorizationStatus == .authorizedAlways || locationAuthorizationStatus == .authorizedWhenInUse
    }
    func requestLocationPermission(completion: ((Bool) -> Void)?) { completion?(isLocationPermissionGranted) }
    func getCurrentLocation() async throws -> CLLocation { CLLocation(latitude: 0, longitude: 0) }
}
