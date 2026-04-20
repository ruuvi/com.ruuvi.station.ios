@testable import RuuviCore
import AVFoundation
import CoreLocation
import UIKit
import UserNotifications
import XCTest

final class RuuviCoreStatefulTests: XCTestCase {
    func testImageCropReturnsOriginalWhenImageAlreadyFits() {
        let sut = RuuviCoreImageImpl()
        let image = makeImage(size: CGSize(width: 40, height: 20))

        let result = sut.cropped(image: image, to: CGSize(width: 100, height: 100))

        XCTAssertEqual(result.size.width, 40)
        XCTAssertEqual(result.size.height, 20)
    }

    func testImageCropScalesImageToFitBoundingRect() {
        let sut = RuuviCoreImageImpl()
        let image = makeImage(size: CGSize(width: 400, height: 200))

        let result = sut.cropped(image: image, to: CGSize(width: 100, height: 100))

        XCTAssertEqual(result.size.width, 100, accuracy: 0.1)
        XCTAssertEqual(result.size.height, 50, accuracy: 0.1)
    }

    func testImageCropScalesTallImageToFitBoundingRect() {
        let sut = RuuviCoreImageImpl()
        let image = makeImage(size: CGSize(width: 200, height: 400))

        let result = sut.cropped(image: image, to: CGSize(width: 100, height: 100))

        XCTAssertEqual(result.size.width, 50, accuracy: 0.1)
        XCTAssertEqual(result.size.height, 100, accuracy: 0.1)
    }

    func testImageAspectScaledCoversWidthConstrainedPath() {
        let image = makeImage(size: CGSize(width: 400, height: 200))

        let result = image.ruuviCoreImageAspectScaled(toFit: CGSize(width: 100, height: 100))

        XCTAssertEqual(result.size.width, 100, accuracy: 0.1)
        XCTAssertEqual(result.size.height, 100, accuracy: 0.1)
    }

    func testImageAspectScaledReturnsOriginalForInvalidTargetSize() {
        let image = makeImage(size: CGSize(width: 40, height: 20))

        let result = image.ruuviCoreImageAspectScaled(toFit: .zero)

        XCTAssertEqual(result.size.width, image.size.width)
        XCTAssertEqual(result.size.height, image.size.height)
    }

    func testPermissionImplUsesInjectedPhotoCameraAndLocationProviders() async {
        let location = LocationPermissionStub()
        location.isGranted = true
        location.status = .authorizedAlways
        let sut = RuuviCorePermissionImpl(
            locationManager: location,
            photoAuthorizationStatusProvider: { .authorized },
            requestPhotoAuthorization: { completion in
                completion(.authorized)
            },
            cameraAuthorizationStatusProvider: { .authorized },
            requestCameraAccess: { completion in
                completion(true)
            }
        )
        let photoExpectation = expectation(description: "photo completion")
        let cameraExpectation = expectation(description: "camera completion")
        let locationExpectation = expectation(description: "location completion")

        sut.requestPhotoLibraryPermission { granted in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(granted)
            photoExpectation.fulfill()
        }
        sut.requestCameraPermission { granted in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(granted)
            cameraExpectation.fulfill()
        }
        sut.requestLocationPermission { granted in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(granted)
            locationExpectation.fulfill()
        }

        XCTAssertTrue(sut.isPhotoLibraryPermissionGranted)
        XCTAssertEqual(sut.photoLibraryAuthorizationStatus, .authorized)
        XCTAssertTrue(sut.isCameraPermissionGranted)
        XCTAssertEqual(sut.cameraAuthorizationStatus, .authorized)
        XCTAssertTrue(sut.isLocationPermissionGranted)
        XCTAssertEqual(sut.locationAuthorizationStatus, .authorizedAlways)
        await fulfillment(of: [photoExpectation, cameraExpectation, locationExpectation], timeout: 1)
    }

    func testPermissionImplMapsDeniedStatesToFalse() async {
        let location = LocationPermissionStub()
        location.isGranted = false
        location.status = .denied
        let sut = RuuviCorePermissionImpl(
            locationManager: location,
            photoAuthorizationStatusProvider: { .denied },
            requestPhotoAuthorization: { completion in
                completion(.denied)
            },
            cameraAuthorizationStatusProvider: { .denied },
            requestCameraAccess: { completion in
                completion(false)
            }
        )
        let photoExpectation = expectation(description: "photo denied")
        let cameraExpectation = expectation(description: "camera denied")
        let locationExpectation = expectation(description: "location denied")

        sut.requestPhotoLibraryPermission { granted in
            XCTAssertFalse(granted)
            photoExpectation.fulfill()
        }
        sut.requestCameraPermission { granted in
            XCTAssertFalse(granted)
            cameraExpectation.fulfill()
        }
        sut.requestLocationPermission { granted in
            XCTAssertFalse(granted)
            locationExpectation.fulfill()
        }

        XCTAssertFalse(sut.isPhotoLibraryPermissionGranted)
        XCTAssertEqual(sut.photoLibraryAuthorizationStatus, .denied)
        XCTAssertFalse(sut.isCameraPermissionGranted)
        XCTAssertEqual(sut.cameraAuthorizationStatus, .denied)
        XCTAssertFalse(sut.isLocationPermissionGranted)
        XCTAssertEqual(sut.locationAuthorizationStatus, .denied)
        await fulfillment(of: [photoExpectation, cameraExpectation, locationExpectation], timeout: 1)
    }

    func testPermissionRequestsAllowNilCompletions() async {
        let location = LocationPermissionStub()
        let sut = RuuviCorePermissionImpl(
            locationManager: location,
            photoAuthorizationStatusProvider: { .denied },
            requestPhotoAuthorization: { completion in
                completion(.denied)
            },
            cameraAuthorizationStatusProvider: { .denied },
            requestCameraAccess: { completion in
                completion(false)
            }
        )

        sut.requestPhotoLibraryPermission(completion: nil)
        sut.requestCameraPermission(completion: nil)
        sut.requestLocationPermission(completion: nil)

        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    func testPermissionImplPublicInitializerBuildsSystemProvidersAndDelegatesLocation() async {
        let location = LocationPermissionStub()
        location.isGranted = true
        location.status = .authorizedWhenInUse
        let sut = RuuviCorePermissionImpl(locationManager: location)
        let locationExpectation = expectation(description: "location completion")

        _ = sut.photoLibraryAuthorizationStatus
        _ = sut.isPhotoLibraryPermissionGranted
        _ = sut.cameraAuthorizationStatus
        _ = sut.isCameraPermissionGranted

        sut.requestLocationPermission { granted in
            XCTAssertTrue(granted)
            locationExpectation.fulfill()
        }

        XCTAssertTrue(sut.isLocationPermissionGranted)
        XCTAssertEqual(sut.locationAuthorizationStatus, .authorizedWhenInUse)
        await fulfillment(of: [locationExpectation], timeout: 1)
    }

    func testLocationImplRequestsAuthorizationWhenStatusIsUndetermined() {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .notDetermined
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { true }
        )

        sut.requestLocationPermission(completion: nil)

        XCTAssertEqual(manager.requestAlwaysAuthorizationCalls, 1)
        XCTAssertTrue(manager.delegate === sut)
        XCTAssertEqual(manager.distanceFilter, 100)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyThreeKilometers)
        XCTAssertEqual(sut.locationAuthorizationStatus, .notDetermined)
    }

    func testLocationImplReturnsCurrentLocationFromDelegateCallback() async throws {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .authorizedWhenInUse
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { true }
        )
        let expectedLocation = CLLocation(latitude: 60.1699, longitude: 24.9384)

        let task = Task {
            try await sut.getCurrentLocation()
        }
        await Task.yield()
        sut.locationManager(CLLocationManager(), didUpdateLocations: [expectedLocation])
        let location = try await task.value

        XCTAssertEqual(manager.startUpdatingLocationCalls, 1)
        XCTAssertEqual(manager.stopUpdatingLocationCalls, 1)
        XCTAssertEqual(location.coordinate.latitude, expectedLocation.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, expectedLocation.coordinate.longitude, accuracy: 0.0001)
    }

    func testLocationImplCompletesPendingPermissionRequestFromAuthorizationCallback() async {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .notDetermined
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { true }
        )
        let granted = expectation(description: "permission callback invoked")

        sut.requestLocationPermission { isGranted in
            XCTAssertTrue(isGranted)
            granted.fulfill()
        }
        sut.locationManager(CLLocationManager(), didChangeAuthorization: .authorizedAlways)

        await fulfillment(of: [granted], timeout: 1)
        XCTAssertEqual(manager.requestAlwaysAuthorizationCalls, 1)
    }

    func testLocationImplRequestPermissionReturnsImmediatelyForGrantedAndDeniedStates() {
        let grantedManager = CoreLocationManagerSpy()
        grantedManager.authorizationStatusValue = .authorizedAlways
        let grantedSut = RuuviCoreLocationImpl(
            locationManager: grantedManager,
            locationServicesEnabled: { true }
        )
        var grantedResult: Bool?

        grantedSut.requestLocationPermission { grantedResult = $0 }

        XCTAssertEqual(grantedResult, true)
        XCTAssertEqual(grantedManager.requestAlwaysAuthorizationCalls, 0)

        let deniedManager = CoreLocationManagerSpy()
        deniedManager.authorizationStatusValue = .denied
        let deniedSut = RuuviCoreLocationImpl(
            locationManager: deniedManager,
            locationServicesEnabled: { true }
        )
        var deniedResult: Bool?

        deniedSut.requestLocationPermission { deniedResult = $0 }

        XCTAssertEqual(deniedResult, false)
        XCTAssertEqual(deniedManager.requestAlwaysAuthorizationCalls, 0)
        XCTAssertTrue(deniedSut.isLocationPermissionDenied)
        XCTAssertFalse(deniedSut.isLocationPermissionNotDetermined)
    }

    func testLocationImplReflectsDisabledServicesAsDenied() {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .authorizedAlways
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { false }
        )

        XCTAssertFalse(sut.isLocationPermissionGranted)
        XCTAssertTrue(sut.isLocationPermissionDenied)
        XCTAssertFalse(sut.isLocationPermissionNotDetermined)
    }

    func testLocationImplThrowsPermissionErrorsBeforeStartingUpdates() async {
        let deniedManager = CoreLocationManagerSpy()
        deniedManager.authorizationStatusValue = .denied
        let deniedSut = RuuviCoreLocationImpl(
            locationManager: deniedManager,
            locationServicesEnabled: { true }
        )

        do {
            _ = try await deniedSut.getCurrentLocation()
            XCTFail("Expected denied error")
        } catch let error as RuuviCoreError {
            guard case .locationPermissionDenied = error else {
                return XCTFail("Unexpected core error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let undeterminedManager = CoreLocationManagerSpy()
        undeterminedManager.authorizationStatusValue = .notDetermined
        let undeterminedSut = RuuviCoreLocationImpl(
            locationManager: undeterminedManager,
            locationServicesEnabled: { true }
        )

        do {
            _ = try await undeterminedSut.getCurrentLocation()
            XCTFail("Expected not determined error")
        } catch let error as RuuviCoreError {
            guard case .locationPermissionNotDetermined = error else {
                return XCTFail("Unexpected core error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLocationImplFailsWhenDelegateReturnsNoLocations() async {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .authorizedAlways
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { true }
        )

        let task = Task {
            try await sut.getCurrentLocation()
        }
        await Task.yield()
        sut.locationManager(CLLocationManager(), didUpdateLocations: [])

        do {
            _ = try await task.value
            XCTFail("Expected current location failure")
        } catch let error as RuuviCoreError {
            guard case .failedToGetCurrentLocation = error else {
                return XCTFail("Unexpected core error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLocationImplResumesWithFailureWhenManagerErrors() async {
        let manager = CoreLocationManagerSpy()
        manager.authorizationStatusValue = .authorizedAlways
        let sut = RuuviCoreLocationImpl(
            locationManager: manager,
            locationServicesEnabled: { true }
        )

        let task = Task {
            try await sut.getCurrentLocation()
        }
        await Task.yield()
        sut.locationManager(CLLocationManager(), didFailWithError: DummyError())

        do {
            _ = try await task.value
            XCTFail("Expected current location failure")
        } catch let error as RuuviCoreError {
            guard case .failedToGetCurrentLocation = error else {
                return XCTFail("Unexpected core error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLocationImplPublicInitializerExposesSystemAuthorizationStatus() {
        let sut = RuuviCoreLocationImpl()
        let expectedStatus = CLLocationManager().authorizationStatus

        XCTAssertEqual(sut.locationAuthorizationStatus, expectedStatus)
        _ = sut.isLocationPermissionGranted
    }

    func testPNImplPersistsTokensAndKeepsTokenIdNilUntilSet() {
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: UserNotificationCenterSpy(),
            application: RemoteNotificationApplicationSpy()
        )
        let refreshedAt = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNil(sut.fcmTokenId)
        sut.pnTokenData = Data([0x01, 0x02])
        sut.fcmToken = "token"
        sut.fcmTokenId = 7
        sut.fcmTokenLastRefreshed = refreshedAt

        XCTAssertEqual(sut.pnTokenData, Data([0x01, 0x02]))
        XCTAssertEqual(sut.fcmToken, "token")
        XCTAssertEqual(sut.fcmTokenId, 7)
        XCTAssertEqual(sut.fcmTokenLastRefreshed, refreshedAt)

        sut.pnTokenData = nil
        sut.fcmToken = nil
        sut.fcmTokenId = nil
        sut.fcmTokenLastRefreshed = nil

        XCTAssertNil(sut.pnTokenData)
        XCTAssertNil(sut.fcmToken)
        XCTAssertNil(sut.fcmTokenId)
        XCTAssertNil(sut.fcmTokenLastRefreshed)
    }

    func testPNImplMapsAuthorizationStatusAndRegistersForRemoteNotifications() async {
        let notificationCenter = UserNotificationCenterSpy()
        notificationCenter.authorizationStatus = .provisional
        let application = RemoteNotificationApplicationSpy()
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            application: application
        )
        let statusExpectation = expectation(description: "status returned")
        let registerExpectation = expectation(description: "register called")
        application.onRegister = {
            registerExpectation.fulfill()
        }

        sut.getRemoteNotificationsAuthorizationStatus { status in
            XCTAssertEqual(status, .authorized)
            statusExpectation.fulfill()
        }
        sut.registerForRemoteNotifications()

        await fulfillment(of: [statusExpectation, registerExpectation], timeout: 1)
        XCTAssertEqual(notificationCenter.requestAuthorizationCalls, 1)
        XCTAssertEqual(application.registerForRemoteNotificationsCalls, 1)
    }

    func testPNImplMapsRemainingAuthorizationStatuses() async {
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let notificationCenter = UserNotificationCenterSpy()
        let application = RemoteNotificationApplicationSpy()
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            application: application
        )

        notificationCenter.authorizationStatus = .denied
        let deniedExpectation = expectation(description: "denied status")
        sut.getRemoteNotificationsAuthorizationStatus { status in
            XCTAssertEqual(status, .denied)
            deniedExpectation.fulfill()
        }

        notificationCenter.authorizationStatus = .notDetermined
        let notDeterminedExpectation = expectation(description: "not determined status")
        sut.getRemoteNotificationsAuthorizationStatus { status in
            XCTAssertEqual(status, .notDetermined)
            notDeterminedExpectation.fulfill()
        }

        notificationCenter.authorizationStatus = .ephemeral
        let ephemeralExpectation = expectation(description: "ephemeral status")
        sut.getRemoteNotificationsAuthorizationStatus { status in
            XCTAssertEqual(status, .notDetermined)
            ephemeralExpectation.fulfill()
        }

        await fulfillment(
            of: [deniedExpectation, notDeterminedExpectation, ephemeralExpectation],
            timeout: 1
        )
    }

    func testPNImplMapsAuthorizedStatusExplicitly() async {
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let notificationCenter = UserNotificationCenterSpy()
        notificationCenter.authorizationStatus = .authorized
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            application: RemoteNotificationApplicationSpy()
        )
        let authorizedExpectation = expectation(description: "authorized status")

        sut.getRemoteNotificationsAuthorizationStatus { status in
            XCTAssertEqual(status, .authorized)
            authorizedExpectation.fulfill()
        }

        await fulfillment(of: [authorizedExpectation], timeout: 1)
    }

    func testPNImplHelpersCoverLegacyStatuses() {
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: .authorized),
            .authorized
        )
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: .provisional),
            .authorized
        )
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: .denied),
            .denied
        )
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: .notDetermined),
            .notDetermined
        )
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: .ephemeral),
            .notDetermined
        )
        XCTAssertEqual(
            RuuviCorePNImpl.authorizationStatus(from: UNAuthorizationStatus(rawValue: 999)!),
            .denied
        )

        XCTAssertEqual(
            RuuviCorePNImpl.legacyAuthorizationStatus(
                isRegisteredForRemoteNotifications: true,
                didAskForRemoteNotificationPermission: false
            ),
            .authorized
        )
        XCTAssertEqual(
            RuuviCorePNImpl.legacyAuthorizationStatus(
                isRegisteredForRemoteNotifications: false,
                didAskForRemoteNotificationPermission: true
            ),
            .denied
        )
        XCTAssertEqual(
            RuuviCorePNImpl.legacyAuthorizationStatus(
                isRegisteredForRemoteNotifications: false,
                didAskForRemoteNotificationPermission: false
            ),
            .notDetermined
        )
    }

    func testPNImplLegacyHelpersPersistPermissionRequestState() {
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let application = RemoteNotificationApplicationSpy()
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: UserNotificationCenterSpy(),
            application: application
        )

        XCTAssertEqual(sut.legacyRemoteNotificationsAuthorizationStatus(), .notDetermined)

        sut.registerForRemoteNotificationsLegacy()

        XCTAssertEqual(application.registerUserNotificationSettingsCalls, 1)
        XCTAssertEqual(application.registerForRemoteNotificationsCalls, 1)
        XCTAssertEqual(sut.legacyRemoteNotificationsAuthorizationStatus(), .denied)

        application.isRegisteredForRemoteNotifications = true

        XCTAssertEqual(sut.legacyRemoteNotificationsAuthorizationStatus(), .authorized)
    }

    func testPNImplSkipsRemoteRegistrationWhenAuthorizationRequestFails() async {
        let notificationCenter = UserNotificationCenterSpy()
        notificationCenter.requestAuthorizationError = DummyError()
        let application = RemoteNotificationApplicationSpy()
        let suiteName = "RuuviCorePNImplTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let sut = RuuviCorePNImpl(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter,
            application: application
        )

        sut.registerForRemoteNotifications()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(notificationCenter.requestAuthorizationCalls, 1)
        XCTAssertEqual(application.registerForRemoteNotificationsCalls, 0)
    }

    func testPNImplPublicInitializerRoundTripsPersistedValues() {
        let sut = RuuviCorePNImpl()
        let originalTokenData = sut.pnTokenData
        let originalFCMToken = sut.fcmToken
        let originalFCMTokenId = sut.fcmTokenId
        let originalRefreshedAt = sut.fcmTokenLastRefreshed
        let refreshedAt = Date(timeIntervalSince1970: 1_710_000_000)

        defer {
            sut.pnTokenData = originalTokenData
            sut.fcmToken = originalFCMToken
            sut.fcmTokenId = originalFCMTokenId
            sut.fcmTokenLastRefreshed = originalRefreshedAt
        }

        sut.pnTokenData = Data([0xAB, 0xCD])
        sut.fcmToken = "public-init-token"
        sut.fcmTokenId = 88
        sut.fcmTokenLastRefreshed = refreshedAt

        XCTAssertEqual(sut.pnTokenData, Data([0xAB, 0xCD]))
        XCTAssertEqual(sut.fcmToken, "public-init-token")
        XCTAssertEqual(sut.fcmTokenId, 88)
        XCTAssertEqual(sut.fcmTokenLastRefreshed, refreshedAt)
    }

}

private final class LocationPermissionStub: RuuviCoreLocation {
    var isGranted = false
    var status: CLAuthorizationStatus = .notDetermined

    var isLocationPermissionGranted: Bool {
        isGranted
    }

    var locationAuthorizationStatus: CLAuthorizationStatus {
        status
    }

    func requestLocationPermission(completion: ((Bool) -> Void)?) {
        completion?(isGranted)
    }

    func getCurrentLocation() async throws -> CLLocation {
        CLLocation(latitude: 0, longitude: 0)
    }
}

private final class CoreLocationManagerSpy: CoreLocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var authorizationStatusValue: CLAuthorizationStatus = .notDetermined
    var distanceFilter: CLLocationDistance = 0
    var desiredAccuracy: CLLocationAccuracy = 0
    var requestAlwaysAuthorizationCalls = 0
    var startUpdatingLocationCalls = 0
    var stopUpdatingLocationCalls = 0

    var authorizationStatus: CLAuthorizationStatus {
        authorizationStatusValue
    }

    func requestAlwaysAuthorization() {
        requestAlwaysAuthorizationCalls += 1
    }

    func startUpdatingLocation() {
        startUpdatingLocationCalls += 1
    }

    func stopUpdatingLocation() {
        stopUpdatingLocationCalls += 1
    }
}

private final class UserNotificationCenterSpy: UserNotificationCentering {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationCalls = 0
    var requestAuthorizationGranted = true
    var requestAuthorizationError: Error?

    func getAuthorizationStatus(
        completionHandler: @escaping @Sendable (UNAuthorizationStatus) -> Void
    ) {
        completionHandler(authorizationStatus)
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping @Sendable (Bool, Error?) -> Void
    ) {
        requestAuthorizationCalls += 1
        completionHandler(requestAuthorizationGranted, requestAuthorizationError)
    }
}

private final class RemoteNotificationApplicationSpy: RemoteNotificationApplicationing {
    var isRegisteredForRemoteNotifications = false
    var registerForRemoteNotificationsCalls = 0
    var registerUserNotificationSettingsCalls = 0
    var lastNotificationSettings: UIUserNotificationSettings?
    var onRegister: (() -> Void)?

    func registerForRemoteNotifications() {
        registerForRemoteNotificationsCalls += 1
        onRegister?()
    }

    func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings) {
        registerUserNotificationSettingsCalls += 1
        lastNotificationSettings = notificationSettings
    }
}

private struct DummyError: Error {}

private func makeImage(size: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        UIColor.red.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}
