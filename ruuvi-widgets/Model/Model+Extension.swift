import Foundation
import RuuviOntology

extension RuuviTagSelectionIntent {
    static var preview: RuuviTagSelectionIntent = {
        let intent = RuuviTagSelectionIntent()
        return intent
    }()
}

extension RuuviTagSensorRecordStruct {
    static func preview() -> RuuviTagSensorRecordStruct {
        return RuuviTagSensorRecordStruct(luid: nil,
                                          date: Date(),
                                          source: .ruuviNetwork,
                                          macId: nil,
                                          rssi: nil,
                                          temperature: Temperature(69.50),
                                          humidity: nil,
                                          pressure: nil,
                                          acceleration: nil,
                                          voltage: nil,
                                          movementCounter: nil,
                                          measurementSequenceNumber: nil,
                                          txPower: nil,
                                          temperatureOffset: 0,
                                          humidityOffset: 0,
                                          pressureOffset: 0)
    }
}

extension RuuviWidgetTag {
    static var preview: RuuviWidgetTag = {
        return RuuviWidgetTag(identifier: nil,
                              display: "Sauna")
    }()
}

extension WidgetSensor {
    static var preview: WidgetSensor = {
        return .temperature
    }()
}

extension SensorSettingsStruct {
    static func settings(from ruuviTag: AnyCloudSensor) -> SensorSettingsStruct {
        return SensorSettingsStruct(luid: ruuviTag.ruuviTagSensor.luid,
                                    macId: ruuviTag.ruuviTagSensor.macId,
                                    temperatureOffset: ruuviTag.offsetTemperature,
                                    temperatureOffsetDate: nil,
                                    humidityOffset: ruuviTag.offsetHumidity,
                                    humidityOffsetDate: nil,
                                    pressureOffset: ruuviTag.offsetPressure,
                                    pressureOffsetDate: nil)
    }
}
