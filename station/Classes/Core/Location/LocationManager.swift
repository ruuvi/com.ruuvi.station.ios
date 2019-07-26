import Foundation
import CoreLocation

protocol LocationManager {
    var isLocationPermissionGranted: Bool { get }
    func requestLocationPermission(completion: ((Bool) -> Void)?)
    func getCurrentLocation(completion: ((CLLocation?) -> Void)?)
}
