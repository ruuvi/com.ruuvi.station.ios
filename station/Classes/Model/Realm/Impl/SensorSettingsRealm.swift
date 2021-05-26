import Foundation
import RealmSwift
import RuuviOntology

class SensorSettingsRealm: Object {
    @objc dynamic var ruuviTagId: String = ""

    let temperatureOffset = RealmOptional<Double>()
    @objc dynamic var temperatureOffsetDate: Date?

    let humidityOffset = RealmOptional<Double>()
    @objc dynamic var humidityOffsetDate: Date?

    let pressureOffset = RealmOptional<Double>()
    @objc dynamic var pressureOffsetDate: Date?

    convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        ruuviTagId = ruuviTag.luid?.value ?? ruuviTag.macId?.value ?? ""
    }
}

extension SensorSettingsRealm {
    var sensorSettings: SensorSettings {
        return SensorSettingsStruct(ruuviTagId: ruuviTagId,
                                    temperatureOffset: temperatureOffset.value,
                                    temperatureOffsetDate: temperatureOffsetDate,
                                    humidityOffset: humidityOffset.value,
                                    humidityOffsetDate: humidityOffsetDate,
                                    pressureOffset: pressureOffset.value,
                                    pressureOffsetDate: pressureOffsetDate)
    }
}
