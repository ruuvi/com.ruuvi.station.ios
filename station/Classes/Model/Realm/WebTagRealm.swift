import RealmSwift

class WebTagRealm: Object {
    @objc dynamic var name: String = ""
    @objc dynamic var uuid: String = ""
    @objc dynamic var providerString: String = WeatherProvider.openWeatherMap.rawValue
    let data = LinkingObjects(fromType: WebTagLocationRealm.self, property: "webTag")
    
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
        self.name = provider.displayName
    }
}

class WebTagLocationRealm: Object {
    
    @objc dynamic var webTag: WebTagRealm?
    
    @objc dynamic var city: String?
    @objc dynamic var country: String?
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
}
