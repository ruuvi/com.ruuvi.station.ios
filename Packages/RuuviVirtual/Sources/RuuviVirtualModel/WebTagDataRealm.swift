import RealmSwift
import Foundation
import RuuviOntology
import RuuviVirtual

public final class WebTagDataRealm: Object {
    @objc public dynamic var webTag: WebTagRealm?
    @objc public dynamic var date: Date = Date()
    @objc public dynamic var location: WebTagLocationRealm?

    public let celsius = RealmProperty<Double?>()
    public let humidity = RealmProperty<Double?>()
    public let pressure = RealmProperty<Double?>()

    public convenience init(webTag: WebTagRealm, data: VirtualData) {
        self.init()
        self.webTag = webTag
        self.celsius.value = data.celsius
        self.humidity.value = data.humidity?.value
        self.pressure.value = data.hPa
    }
}

extension WebTagDataRealm {
    public var record: VirtualTagSensorRecord? {
        guard let id = webTag?.id else {
            return nil
        }
        let t = Temperature(celsius.value)
        let h = Humidity(relative: humidity.value, temperature: t)
        let p = Pressure(pressure.value)
        return VirtualTagSensorRecordStruct(
            sensorId: id,
            date: date,
            temperature: t,
            humidity: h,
            pressure: p,
            location: location?.location
        )
    }
}
