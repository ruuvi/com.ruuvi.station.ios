import CoreLocation
import Foundation

@MainActor
public protocol RuuviCoreLocation {
    var isLocationPermissionGranted: Bool { get }
    var locationAuthorizationStatus: CLAuthorizationStatus { get }
    func requestLocationPermission(completion: ((Bool) -> Void)?)
    func getCurrentLocation() async throws -> CLLocation
}
