import RealmSwift

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
        if let celsius = celsius.value {
            return (celsius * 9.0/5.0) + 32.0
        } else {
            return nil
        }
    }
    
    var kelvin: Double? {
        if let celsius = celsius.value {
            return celsius + 273.15
        } else {
            return nil
        }
    }
}
