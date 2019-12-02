import RealmSwift
import Foundation

class WebTagDataRealm: Object {
    @objc dynamic var webTag: WebTagRealm?
    @objc dynamic var date: Date = Date()
    @objc dynamic var location: WebTagLocationRealm?

    let celsius = RealmOptional<Double>()
    let humidity = RealmOptional<Double>()
    let pressure = RealmOptional<Double>()

    convenience init(webTag: WebTagRealm, data: WPSData) {
        self.init()
        self.webTag = webTag
        self.celsius.value = data.celsius
        self.humidity.value = data.humidity
        self.pressure.value = data.pressure
    }

    var fahrenheit: Double? {
        return celsius.value?.fahrenheit
    }

    var kelvin: Double? {
        return celsius.value?.kelvin
    }
}
