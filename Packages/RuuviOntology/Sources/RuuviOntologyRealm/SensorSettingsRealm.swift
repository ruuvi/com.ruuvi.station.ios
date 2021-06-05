import Foundation
import RealmSwift
import RuuviOntology

public class SensorSettingsRealm: Object {
    @objc public dynamic var luid: String?
    @objc public dynamic var macId: String?

    public let temperatureOffset = RealmOptional<Double>()
    @objc public dynamic var temperatureOffsetDate: Date?

    public let humidityOffset = RealmOptional<Double>()
    @objc public dynamic var humidityOffsetDate: Date?

    public let pressureOffset = RealmOptional<Double>()
    @objc public dynamic var pressureOffsetDate: Date?

    public convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        luid = ruuviTag.luid?.value
        macId = ruuviTag.macId?.value
    }
}

extension SensorSettingsRealm {
    public var sensorSettings: SensorSettings {
        return SensorSettingsStruct(
            luid: luid?.luid,
            macId: macId?.mac,
            temperatureOffset: temperatureOffset.value,
            temperatureOffsetDate: temperatureOffsetDate,
            humidityOffset: humidityOffset.value,
            humidityOffsetDate: humidityOffsetDate,
            pressureOffset: pressureOffset.value,
            pressureOffsetDate: pressureOffsetDate
        )
    }
}
