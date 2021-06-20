import Foundation
import CoreLocation

public protocol Location {
    var city: String? { get }
    var country: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

extension Location {
    public var cityCommaCountry: String? {
        if let city = city, let country = country {
            return city + ", " + country
        } else if let city = city {
            return city
        } else if let country = country {
            return country
        } else {
            return nil
        }
    }
}
