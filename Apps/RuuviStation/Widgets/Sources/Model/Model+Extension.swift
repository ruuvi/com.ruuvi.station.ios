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
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date(),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(69.50),
            humidity: nil,
            pressure: nil,
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            pm1: nil,
            pm25: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
    }
}

extension RuuviWidgetTag {
    static var preview: RuuviWidgetTag = .init(
        identifier: nil,
        display: "Sauna"
    )
}

extension WidgetSensor {
    static var preview: WidgetSensor = .temperature
}

extension SensorSettingsStruct {
    static func settings(from ruuviTag: AnyCloudSensor) -> SensorSettingsStruct {
        SensorSettingsStruct(
            luid: ruuviTag.ruuviTagSensor.luid,
            macId: ruuviTag.ruuviTagSensor.macId,
            temperatureOffset: ruuviTag.offsetTemperature,
            humidityOffset: ruuviTag.offsetHumidity,
            pressureOffset: ruuviTag.offsetPressure
        )
    }
}
