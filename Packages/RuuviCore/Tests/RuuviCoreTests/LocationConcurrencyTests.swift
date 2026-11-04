import CoreLocation
import XCTest
@testable import RuuviCore
#if SWIFT_PACKAGE
    @testable import RuuviCoreLocation
#endif

final class LocationConcurrencyTests: XCTestCase {
    @MainActor func testPermissionRequestsShareOneSystemPromptAndCompleteEveryCaller() {
        let manager = LocationManagerSpy()
        manager.authorizationStatus = .notDetermined
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
        var results = [Bool]()
        service.requestLocationPermission { results.append($0) }
        service.requestLocationPermission { results.append($0) }
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertTrue(results.isEmpty)
        manager.authorizationStatus = .authorizedWhenInUse
        service.locationManagerDidChangeAuthorization(CLLocationManager())
        XCTAssertEqual(results, [true, true])
        service.locationManagerDidChangeAuthorization(CLLocationManager())
        XCTAssertEqual(results.count, 2)
        service.requestLocationPermission { results.append($0) }
        XCTAssertEqual(results, [true, true, true])
        XCTAssertEqual(manager.permissionRequests, 1)
    }

    @MainActor func testDeniedRestrictedAndUndeterminedRequestsFailWithoutStartingGPS() async {
        for status in [CLAuthorizationStatus.denied, .restricted, .notDetermined] {
            let manager = LocationManagerSpy()
            manager.authorizationStatus = status
            let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
            do { _ = try await service.getCurrentLocation(); XCTFail("Permission must be checked") } catch {
                guard let core = error as? RuuviCoreError else { return XCTFail("Unexpected error: \(error)") }
                switch (status, core) {
                case (.notDetermined, .locationPermissionNotDetermined), (.denied, .locationPermissionDenied),
                    (.restricted, .locationPermissionDenied):
                    break
                default: XCTFail("Wrong permission error")
                }
            }
            XCTAssertEqual(manager.starts, 0)
        }
        let manager = LocationManagerSpy()
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { false })
        XCTAssertFalse(service.isLocationPermissionGranted)
        var result: Bool?
        service.requestLocationPermission { result = $0 }
        XCTAssertEqual(result, false)
        XCTAssertEqual(manager.permissionRequests, 0)
    }

    @MainActor func testOneLocationCompletesEveryConcurrentCaller() async throws {
        let manager = LocationManagerSpy()
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
        let started = expectation(description: "Both location requests registered")
        started.expectedFulfillmentCount = 2
        manager.onStart = { started.fulfill() }
        let first = Task { try await service.getCurrentLocation() }
        let second = Task { try await service.getCurrentLocation() }
        await fulfillment(of: [started], timeout: 3)
        let latest = CLLocation(latitude: 60.17, longitude: 24.94)
        service.locationManager(
            CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 0, longitude: 0), latest])
        let results = try await [first.value, second.value]
        XCTAssertTrue(results.allSatisfy { $0 === latest })
        XCTAssertEqual(manager.stops, 1)
    }

    @MainActor func testCancellingOneCallerPreservesOtherLocationRequests() async throws {
        let manager = LocationManagerSpy()
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
        let started = expectation(description: "Concurrent requests started")
        started.expectedFulfillmentCount = 2
        manager.onStart = { started.fulfill() }
        let cancelled = Task { try await service.getCurrentLocation() }
        let remaining = Task { try await service.getCurrentLocation() }
        await fulfillment(of: [started], timeout: 3)
        cancelled.cancel()
        do { _ = try await cancelled.value; XCTFail("Cancelled request succeeded") } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(manager.stops, 0)
        service.locationManager(CLLocationManager(), didUpdateLocations: [CLLocation(latitude: 1, longitude: 2)])
        let location = try await remaining.value
        XCTAssertEqual(location.coordinate.latitude, 1)
        XCTAssertEqual(manager.stops, 1)
    }

    @MainActor func testCancelledLastCallerStopsGPSAndLateCallbacksAreHarmless() async {
        let manager = LocationManagerSpy()
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
        let started = expectation(description: "Location started")
        manager.onStart = { started.fulfill() }
        let task = Task { try await service.getCurrentLocation() }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request succeeded") } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertEqual(manager.stops, 1)
        service.locationManager(CLLocationManager(), didUpdateLocations: [])
        service.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))
    }

    @MainActor func testRevokedAuthorizationFailsPendingRequest() async {
        let manager = LocationManagerSpy()
        let service = RuuviCoreLocationImpl(manager: manager, servicesEnabled: { true })
        let started = expectation(description: "Location started")
        manager.onStart = { started.fulfill() }
        let task = Task { try await service.getCurrentLocation() }
        await fulfillment(of: [started], timeout: 3)
        manager.authorizationStatus = .denied
        service.locationManagerDidChangeAuthorization(CLLocationManager())
        do { _ = try await task.value; XCTFail("Revoked permission succeeded") } catch {
            guard let core = error as? RuuviCoreError, case .locationPermissionDenied = core else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(manager.stops, 1)
    }
}

@MainActor private final class LocationManagerSpy: LocationManagerClient {
    weak var delegate: CLLocationManagerDelegate?
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var distanceFilter: CLLocationDistance = 0
    var desiredAccuracy: CLLocationAccuracy = 0
    var permissionRequests = 0
    var starts = 0
    var stops = 0
    var onStart: (() -> Void)?
    func requestAlwaysAuthorization() { permissionRequests += 1 }
    func startUpdatingLocation() { starts += 1; onStart?() }
    func stopUpdatingLocation() { stops += 1 }
}
