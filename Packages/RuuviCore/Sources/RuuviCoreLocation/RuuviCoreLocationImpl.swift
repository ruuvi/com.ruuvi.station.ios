import CoreLocation
import Foundation

@MainActor
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
            guard getCurrentLocationContinuation == nil else {
                continuation.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
                return
            }
            getCurrentLocationContinuation = continuation
            locationManager.startUpdatingLocation()
        }
    }
}

extension RuuviCoreLocationImpl: CLLocationManagerDelegate {
    public func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestLocationPermissionCallback?(status == .authorizedWhenInUse || status == .authorizedAlways)
        requestLocationPermissionCallback = nil
    }

    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        if let location = locations.last {
            getCurrentLocationContinuation?.resume(returning: location)
        } else {
            getCurrentLocationContinuation?.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
        }
        getCurrentLocationContinuation = nil
    }

    public func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
        getCurrentLocationContinuation?.resume(throwing: RuuviCoreError.failedToGetCurrentLocation)
        getCurrentLocationContinuation = nil
    }
}
