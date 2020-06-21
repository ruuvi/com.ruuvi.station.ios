import Foundation
import CoreLocation

protocol LocationPersistence {
    func locations(for coordinate: CLLocationCoordinate2D) -> [Location]?
    func setLocations(_ locations: [Location], for coordinate: CLLocationCoordinate2D)
}
