#if SWIFT_PACKAGE
    import RuuviCore
#endif
import CoreLocation
import Foundation

@MainActor
protocol LocationManagerClient: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var distanceFilter: CLLocationDistance { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationManagerClient {}

@MainActor
public final class RuuviCoreLocationImpl: NSObject, RuuviCoreLocation {
    public var isLocationPermissionGranted: Bool {
        servicesEnabled()
            && [.authorizedWhenInUse, .authorizedAlways].contains(locationManager.authorizationStatus)
    }

    public var locationAuthorizationStatus: CLAuthorizationStatus { locationManager.authorizationStatus }

    var isLocationPermissionDenied: Bool {
        !servicesEnabled()
            || [.denied, .restricted].contains(locationManager.authorizationStatus)
    }

    var isLocationPermissionNotDetermined: Bool { locationManager.authorizationStatus == .notDetermined }

    private var managerOverride: LocationManagerClient?
    private var servicesEnabled: () -> Bool = { CLLocationManager.locationServicesEnabled() }
    private lazy var locationManager: LocationManagerClient = {
        let manager: LocationManagerClient = managerOverride ?? CLLocationManager()
        manager.delegate = self
        manager.distanceFilter = 100
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        return manager
    }()
    private var permissionRequestInFlight = false
    private var permissionCallbacks = [(Bool) -> Void]()
    private var locationRequests = [UUID: CheckedContinuation<CLLocation, Error>]()

    // Dependency containers may construct the service off-main. The manager is created
    // lazily on the main actor so its delegate callbacks use the main run loop.
    public nonisolated override init() { super.init() }

    init(manager: LocationManagerClient, servicesEnabled: @escaping () -> Bool) {
        managerOverride = manager
        self.servicesEnabled = servicesEnabled
        super.init()
    }

    public func requestLocationPermission(completion: ((Bool) -> Void)?) {
        if isLocationPermissionGranted {
            completion?(true)
        } else if isLocationPermissionDenied {
            completion?(false)
        } else {
            if let completion { permissionCallbacks.append(completion) }
            if !permissionRequestInFlight {
                permissionRequestInFlight = true
                locationManager.requestAlwaysAuthorization()
            }
        }
    }

    public func getCurrentLocation() async throws -> CLLocation {
        try Task.checkCancellation()
        if isLocationPermissionDenied { throw RuuviCoreError.locationPermissionDenied }
        if isLocationPermissionNotDetermined { throw RuuviCoreError.locationPermissionNotDetermined }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                locationRequests[id] = continuation
                locationManager.startUpdatingLocation()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                locationRequests.removeValue(forKey: id)?.resume(throwing: CancellationError())
                if locationRequests.isEmpty { locationManager.stopUpdatingLocation() }
            }
        }
    }

    private func completeLocations(_ result: Result<CLLocation, Error>) {
        locationManager.stopUpdatingLocation()
        let requests = locationRequests.values
        locationRequests.removeAll()
        for request in requests { request.resume(with: result) }
    }
}

extension RuuviCoreLocationImpl: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationManager.authorizationStatus != .notDetermined else { return }
        permissionRequestInFlight = false
        let callbacks = permissionCallbacks
        permissionCallbacks.removeAll()
        for callback in callbacks { callback(isLocationPermissionGranted) }
        if isLocationPermissionDenied {
            completeLocations(.failure(RuuviCoreError.locationPermissionDenied))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            completeLocations(.success(location))
        } else {
            completeLocations(.failure(RuuviCoreError.failedToGetCurrentLocation))
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completeLocations(.failure(error))
    }
}
