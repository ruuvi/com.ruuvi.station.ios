import CoreLocation
import Foundation
import Future

public protocol RuuviCoreLocation {
    var isLocationPermissionGranted: Bool { get }
    var locationAuthorizationStatus: CLAuthorizationStatus { get }
    func requestLocationPermission(completion: ((Bool) -> Void)?)
    func getCurrentLocation() -> Future<CLLocation, RuuviCoreError>
}
