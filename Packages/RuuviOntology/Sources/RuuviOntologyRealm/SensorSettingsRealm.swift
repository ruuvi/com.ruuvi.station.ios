import Foundation
import RealmSwift
import RuuviOntology

public class SensorSettingsRealm: Object {
    @objc public dynamic var luid: String?
    @objc public dynamic var macId: String?

    public let temperatureOffset = RealmProperty<Double?>()
    @objc public dynamic var temperatureOffsetDate: Date?

    public let humidityOffset = RealmProperty<Double?>()
    @objc public dynamic var humidityOffsetDate: Date?

    public let pressureOffset = RealmProperty<Double?>()
    @objc public dynamic var pressureOffsetDate: Date?

    public convenience init(ruuviTag: RuuviTagSensor) {
        self.init()
        luid = ruuviTag.luid?.value
        macId = ruuviTag.macId?.value
    }

    public convenience init(settings: SensorSettings) {
        self.init()
        luid = settings.luid?.value
        macId = settings.macId?.value
        temperatureOffset.value = settings.temperatureOffset
        temperatureOffsetDate = settings.temperatureOffsetDate
        humidityOffset.value = settings.humidityOffset
        humidityOffsetDate = settings.humidityOffsetDate
        pressureOffset.value = settings.pressureOffset
        pressureOffsetDate = settings.pressureOffsetDate
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
