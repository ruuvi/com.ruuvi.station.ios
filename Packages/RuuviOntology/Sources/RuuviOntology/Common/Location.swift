import CoreLocation
import Foundation

public protocol Location: Sendable {
    var city: String? { get }
    var state: String? { get }
    var country: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

public extension Location {
    var cityCommaCountry: String? {
        if let city, let country {
            city + ", " + country
        } else if let city {
            city
        } else if let country {
            country
        } else {
            nil
        }
    }

    var description: String? {
        if let city, let state {
            city + ", " + state
        } else if let city, let country {
            city + ", " + country
        } else if let city {
            city
        } else if let state {
            state
        } else if let country {
            country
        } else {
            nil
        }
    }
}
