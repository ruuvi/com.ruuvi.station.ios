import Foundation
import Future
import CoreLocation

protocol LocationService {
    func search(query: String) -> Future<[Location], RUError>
    func reverseGeocode(coordinate: CLLocationCoordinate2D) -> Future<[Location], RUError>
}

protocol Location {
    var city: String? { get }
    var country: String? { get }
    var coordinate: CLLocationCoordinate2D { get }
}

extension Location {
    var cityCommaCountry: String? {
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
