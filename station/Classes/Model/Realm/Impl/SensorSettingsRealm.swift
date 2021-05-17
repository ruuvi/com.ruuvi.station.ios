import Foundation
import RealmSwift

class SensorSettingsRealm: Object {
    @objc dynamic var tagId: String? = nil
    @objc dynamic var webTag: WebTagRealm?
    
    let temperatureOffset = RealmOptional<Double>()
    @objc dynamic var temperatureOffsetDate: Date? = nil
    
    let humidityOffset = RealmOptional<Double>()
    @objc dynamic var humidityOffsetDate: Date? = nil
    
    let pressureOffset = RealmOptional<Double>()
    @objc dynamic var pressureOffsetDate: Date? = nil

    convenience init(webTag: WebTagRealm) {
        self.init()
        self.webTag = webTag
    }
    
    convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        tagId = ruuviTag.luid?.value
    }
}

extension SensorSettingsRealm {
    var sensorSettings: SensorSettings {
        return SensorSettingsStruct(ruuviTagId: tagId!,
                                    temperatureOffset: temperatureOffset.value,
                                    temperatureOffsetDate: temperatureOffsetDate,
                                    humidityOffset: humidityOffset.value,
                                    humidityOffsetDate: humidityOffsetDate,
                                    pressureOffset: pressureOffset.value,
                                    pressureOffsetDate: pressureOffsetDate)
    }
}
