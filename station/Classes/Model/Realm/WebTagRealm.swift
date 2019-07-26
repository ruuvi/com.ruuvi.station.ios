import RealmSwift

class WebTagRealm: Object {
    @objc dynamic var uuid: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var provider: String = WeatherProvider.openWeatherMap.name
}
