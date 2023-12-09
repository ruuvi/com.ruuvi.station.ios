import CoreLocation
import Foundation
import Future

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
    private var getCurrentLocationPromise: Promise<CLLocation, RuuviCoreError>?

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

    public func getCurrentLocation() -> Future<CLLocation, RuuviCoreError> {
        let promise = Promise<CLLocation, RuuviCoreError>()
        if isLocationPermissionDenied {
            promise.fail(error: .locationPermissionDenied)
            return promise.future
        } else if isLocationPermissionNotDetermined {
            promise.fail(error: .locationPermissionNotDetermined)
            return promise.future
        } else {
            getCurrentLocationPromise = promise
            locationManager.startUpdatingLocation()
            return promise.future
        }
    }
}

extension RuuviCoreLocationImpl: CLLocationManagerDelegate {
    public func locationManager(_: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestLocationPermissionCallback?(status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    public func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        if let location = locations.last {
            getCurrentLocationPromise?.succeed(value: location)
        } else {
            getCurrentLocationPromise?.fail(error: .failedToGetCurrentLocation)
        }
    }

    public func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }
}
