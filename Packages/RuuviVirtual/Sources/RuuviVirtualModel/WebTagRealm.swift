import RealmSwift
import CoreLocation
import RuuviOntology

public final class WebTagRealm: Object {
    @objc public dynamic var name: String = ""
    @objc public dynamic var uuid: String = ""
    @objc dynamic var providerString: String = VirtualProvider.openWeatherMap.rawValue
    @objc public dynamic var location: WebTagLocationRealm?

    public let data = LinkingObjects(fromType: WebTagDataRealm.self, property: "webTag")

    public var provider: VirtualProvider {
        if let provider = VirtualProvider(rawValue: providerString) {
            return provider
        } else {
            return .openWeatherMap
        }
    }

    override public static func primaryKey() -> String {
        return "uuid"
    }

    public convenience init(uuid: String, provider: VirtualProvider) {
        self.init()
        self.uuid = uuid
        self.providerString = provider.rawValue
    }
}

public final class WebTagLocationRealm: Object {
    let webTags = LinkingObjects(fromType: WebTagRealm.self, property: "location")

    @objc public dynamic var city: String?
    @objc public dynamic var state: String?
    @objc public dynamic var country: String?
    @objc public dynamic var latitude: Double = 0
    @objc public dynamic var longitude: Double = 0
    @objc public dynamic var compoundKey: String = UUID().uuidString

    override public static func primaryKey() -> String? {
        return "compoundKey"
    }

    public convenience init(location: Location) {
        self.init()
        city = location.city
        state = location.state
        country = location.country
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        compoundKey = "\(latitude)" + "\(longitude)"
    }
}

extension WebTagLocationRealm {
    public var location: Location {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return LocationWebTag(city: city,
                              state: state,
                              country: country,
                              coordinate: coordinate)
    }
}

private struct LocationWebTag: Location {
    var city: String?
    var state: String?
    var country: String?
    var coordinate: CLLocationCoordinate2D
}

extension WebTagRealm {
    public var lastRecord: VirtualTagSensorRecord? {
        return data.last?.record
    }
}
