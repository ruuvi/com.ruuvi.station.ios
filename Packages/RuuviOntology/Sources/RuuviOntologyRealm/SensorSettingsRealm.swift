import Foundation
import RealmSwift
import RuuviOntology

public class SensorSettingsRealm: Object {
    @objc public dynamic var ruuviTagId: String = ""

    public let temperatureOffset = RealmOptional<Double>()
    @objc public dynamic var temperatureOffsetDate: Date?

    public let humidityOffset = RealmOptional<Double>()
    @objc public dynamic var humidityOffsetDate: Date?

    public let pressureOffset = RealmOptional<Double>()
    @objc public dynamic var pressureOffsetDate: Date?

    public convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        ruuviTagId = ruuviTag.luid?.value ?? ruuviTag.macId?.value ?? ""
    }
}

extension SensorSettingsRealm {
    public var sensorSettings: SensorSettings {
        return SensorSettingsStruct(
            ruuviTagId: ruuviTagId,
            temperatureOffset: temperatureOffset.value,
            temperatureOffsetDate: temperatureOffsetDate,
            humidityOffset: humidityOffset.value,
            humidityOffsetDate: humidityOffsetDate,
            pressureOffset: pressureOffset.value,
            pressureOffsetDate: pressureOffsetDate
        )
    }
}
