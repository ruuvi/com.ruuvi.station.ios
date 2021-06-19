import Foundation
import CoreLocation

public protocol Location {
    var city: String? { get }
    var country: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}
