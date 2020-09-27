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
        self.humidity.value = data.relativeHumidity
        self.pressure.value = data.hPa
    }
}
extension WebTagDataRealm {
    var record: RuuviTagSensorRecord? {
        guard let id = webTag?.id else {
            return nil
        }
        let t = Temperature(celsius.value)
        let h = Humidity(relative: humidity.value, temperature: t)
        let p = Pressure(pressure.value)
        return RuuviTagSensorRecordStruct(ruuviTagId: id,
                                          date: date,
                                          macId: nil,
                                          rssi: nil,
                                          temperature: t,
                                          humidity: h,
                                          pressure: p,
                                          acceleration: nil,
                                          voltage: nil,
                                          movementCounter: nil,
                                          measurementSequenceNumber: nil,
                                          txPower: nil)
    }
}
