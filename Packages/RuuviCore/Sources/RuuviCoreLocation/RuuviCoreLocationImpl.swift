import CoreLocation
import Foundation

public final class RuuviCoreLocationImpl: NSObject, RuuviCoreLocation {
    public var isLocationPermissionGranted: Bool {
        CLLocationManager.locationServicesEnabled()
            && (locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways)
    }

    public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    var isLocationPermissionDenied: Bool {
        !CLLocationManager.locationServicesEnabled()
            || locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .denied
    }

    var isLocationPermissionNotDetermined: Bool {
        locationManager.authorizationStatus == .notDetermined
    }

    private let locationManager = CLLocationManager()
    private var requestLocationPermissionCallback: ((Bool) -> Void)?
    private var getCurrentLocationContinuation: CheckedContinuation<CLLocation, Error>?

    override public init() {
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = 100
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    public func requestLocationPermission(completion: ((Bool) -> Void)?) {
        if isLocationPermissionGranted {
            completion?(true)
        } else if isLocationPermissionDenied {
            completion?(false)
        } else {
            requestLocationPermissionCallback = completion
            locationManager.requestAlwaysAuthorization()
        }
    }

    public func getCurrentLocation() async throws -> CLLocation {
        if isLocationPermissionDenied {
            throw RuuviCoreError.locationPermissionDenied
        } else if isLocationPermissionNotDetermined {
            throw RuuviCoreError.locationPermissionNotDetermined
        }

        return try await withCheckedThrowingContinuation { continuation in
            if let pendingContinuation = getCurrentLocationContinuation {
                getCurrentLocationContinuation = nil
                pendingContinuation.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
            }

            getCurrentLocationContinuation = continuation
            locationManager.startUpdatingLocation()
        }
    }
}

extension RuuviCoreLocationImpl: CLLocationManagerDelegate {
    public func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestLocationPermissionCallback?(status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        guard let continuation = getCurrentLocationContinuation else {
            return
        }

        getCurrentLocationContinuation = nil

        if let location = locations.last {
            continuation.resume(returning: location)
        } else {
            continuation.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
        }
    }

    public func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        locationManager.stopUpdatingLocation()

        if let continuation = getCurrentLocationContinuation {
            getCurrentLocationContinuation = nil
            continuation.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
        }

        print(error.localizedDescription)
    }
}
