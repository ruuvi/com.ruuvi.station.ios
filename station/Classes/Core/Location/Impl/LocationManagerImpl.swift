import Foundation
import CoreLocation
import Future

class LocationManagerImpl: NSObject, LocationManager {

    var isLocationPermissionGranted: Bool {
        get {
            return CLLocationManager.locationServicesEnabled()
                && (CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways)
        }
    }

    var isLocationPermissionDenied: Bool {
        return !CLLocationManager.locationServicesEnabled()
            || CLLocationManager.authorizationStatus() == .denied || CLLocationManager.authorizationStatus() == .denied
    }

    var isLocationPermissionNotDetermined: Bool {
        return CLLocationManager.authorizationStatus() == .notDetermined
    }

    private var locationManager: CLLocationManager
    private var requestLocationPermissionCallback: ((Bool) -> Void)?
    private var getCurrentLocationPromise: Promise<CLLocation, RUError>?

    override init() {
        locationManager = CLLocationManager()
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = 100
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func requestLocationPermission(completion: ((Bool) -> Void)?) {
        if isLocationPermissionGranted {
            completion?(true)
        } else if isLocationPermissionDenied {
            completion?(false)
        } else {
            requestLocationPermissionCallback = completion
            locationManager.requestWhenInUseAuthorization()
        }
    }

    func getCurrentLocation() -> Future<CLLocation, RUError> {
        let promise = Promise<CLLocation, RUError>()
        if isLocationPermissionDenied {
            promise.fail(error: .core(.locationPermissionDenied))
            return promise.future
        } else if isLocationPermissionNotDetermined {
            promise.fail(error: .core(.locationPermissionNotDetermined))
            return promise.future
        } else {
            getCurrentLocationPromise = promise
            locationManager.startUpdatingLocation()
            return promise.future
        }
    }
}

extension LocationManagerImpl: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        requestLocationPermissionCallback?(status == .authorizedWhenInUse || status == .authorizedAlways)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        if let location = locations.last {
            getCurrentLocationPromise?.succeed(value: location)
        } else {
            getCurrentLocationPromise?.fail(error: .core(.failedToGetCurrentLocation))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error.localizedDescription)
    }

}
