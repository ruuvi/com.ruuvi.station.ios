import Foundation
import CoreLocation
import RuuviOntology

class LocationAppleClass: NSObject, NSCoding {
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    init(location: Location) {
        city = location.city
        state = location.state
        country = location.country
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
    }

    required init?(coder: NSCoder) {
        city = coder.decodeObject(forKey: "city") as? String
        state = coder.decodeObject(forKey: "state") as? String
        country = coder.decodeObject(forKey: "country") as? String
        latitude = coder.decodeDouble(forKey: "latitude")
        longitude = coder.decodeDouble(forKey: "longitude")
    }

    func encode(with coder: NSCoder) {
        coder.encode(city, forKey: "city")
        coder.encode(state, forKey: "state")
        coder.encode(country, forKey: "country")
        coder.encode(latitude, forKey: "latitude")
        coder.encode(longitude, forKey: "longitude")
    }
}
extension LocationAppleClass: Location {
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude,
                                      longitude: longitude)
    }

    var asStruct: LocationApple {
        return LocationApple(city: city,
                             state: state,
                             country: country,
                             coordinate: coordinate)
    }
}
