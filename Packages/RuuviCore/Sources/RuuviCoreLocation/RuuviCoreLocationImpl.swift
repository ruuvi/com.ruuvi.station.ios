import CoreLocation
import Foundation

protocol CoreLocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var distanceFilter: CLLocationDistance { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }

    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: CoreLocationManaging {}

public final class RuuviCoreLocationImpl: NSObject, RuuviCoreLocation {
    private let locationManager: CoreLocationManaging
    private let locationServicesEnabled: () -> Bool

    public var isLocationPermissionGranted: Bool {
        locationServicesEnabled()
            && (locationManager.authorizationStatus == .authorizedWhenInUse
                || locationManager.authorizationStatus == .authorizedAlways)
    }

    public var locationAuthorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    var isLocationPermissionDenied: Bool {
        !locationServicesEnabled()
            || locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .denied
    }

    var isLocationPermissionNotDetermined: Bool {
        locationManager.authorizationStatus == .notDetermined
    }

    private var requestLocationPermissionCallback: ((Bool) -> Void)?
    private var getCurrentLocationContinuation: CheckedContinuation<CLLocation, Error>?

    override public init() {
        locationManager = CLLocationManager()
        locationServicesEnabled = CLLocationManager.locationServicesEnabled
        super.init()
        locationManager.delegate = self
        locationManager.distanceFilter = 100
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    init(
        locationManager: CoreLocationManaging,
        locationServicesEnabled: @escaping () -> Bool
    ) {
        self.locationManager = locationManager
        self.locationServicesEnabled = locationServicesEnabled
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
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                getCurrentLocationContinuation = continuation
                locationManager.startUpdatingLocation()
            }
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
