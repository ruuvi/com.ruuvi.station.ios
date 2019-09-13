import RealmSwift
import CoreLocation

class WebTagRealm: Object {
    @objc dynamic var name: String = ""
    @objc dynamic var uuid: String = ""
    @objc dynamic var providerString: String = WeatherProvider.openWeatherMap.rawValue
    @objc dynamic var location: WebTagLocationRealm?
    
    let data = LinkingObjects(fromType: WebTagDataRealm.self, property: "webTag")
    
    var provider: WeatherProvider {
        if let provider = WeatherProvider(rawValue: providerString) {
            return provider
        } else {
            return .openWeatherMap
        }
    }
    
    override static func primaryKey() -> String {
        return "uuid"
    }
    
    convenience init(uuid: String, provider: WeatherProvider) {
        self.init()
        self.uuid = uuid
        self.providerString = provider.rawValue
    }
}

class WebTagLocationRealm: Object {
    
    let webTags = LinkingObjects(fromType: WebTagRealm.self, property: "location")
    
    @objc dynamic var city: String?
    @objc dynamic var country: String?
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
}

extension WebTagLocationRealm {
    var location: Location {
        return LocationWebTag(city: city, country: country, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
}

private struct LocationWebTag: Location {
    var city: String?
    var country: String?
    var coordinate: CLLocationCoordinate2D
}
