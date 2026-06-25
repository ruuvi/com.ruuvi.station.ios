import Foundation
import RuuviOntology

extension RuuviTagSensorRecordStruct {
    static func preview() -> RuuviTagSensorRecordStruct {
        previewSauna()
    }

    static func previewSauna() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date(),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(78.5),
            humidity: Humidity(relative: 0.214, temperature: Temperature(78.5)),
            pressure: Pressure(1006.20),
            acceleration: nil,
            voltage: nil,
            movementCounter: 2,
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

    static func previewLivingRoom() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-90),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(20.6),
            humidity: Humidity(relative: 0.488, temperature: Temperature(20.6)),
            pressure: Pressure(1013.40),
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

    static func previewBedroom() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-55),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(19.4),
            humidity: Humidity(relative: 0.536, temperature: Temperature(19.4)),
            pressure: Pressure(1013.20),
            acceleration: nil,
            voltage: Voltage(value: 2.91, unit: .volts),
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

    static func previewKitchen() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-75),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(24.2),
            humidity: Humidity(relative: 0.612, temperature: Temperature(24.2)),
            pressure: Pressure(1013.10),
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

    static func previewOutdoor() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-60),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(11.6),
            humidity: Humidity(relative: 0.776, temperature: Temperature(11.6)),
            pressure: Pressure(1014.00),
            acceleration: nil,
            voltage: Voltage(value: 2.88, unit: .volts),
            movementCounter: 24,
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

    static func previewAirC044() -> RuuviTagSensorRecordStruct {
        let temperature = Temperature(21.8)
        return RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-30),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 6,
            temperature: temperature,
            humidity: Humidity(relative: 0.462, temperature: temperature),
            pressure: Pressure(1013.20),
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: 3248,
            txPower: nil,
            pm1: 1,
            pm25: 2,
            pm4: 2,
            pm10: 2,
            co2: 836,
            voc: 104,
            nox: 1,
            luminance: 280,
            dbaInstant: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0,
            humidityOffset: 0,
            pressureOffset: 0
        )
    }

    static func previewAirOld() -> RuuviTagSensorRecordStruct {
        let temperature = Temperature(23.10)
        return RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-180),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 6,
            temperature: temperature,
            humidity: Humidity(relative: 0.387, temperature: temperature),
            pressure: Pressure(1006.50),
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: 2870,
            txPower: nil,
            pm1: 0,
            pm25: 0,
            pm4: 0,
            pm10: 0,
            co2: 820,
            voc: 146,
            nox: 1,
            luminance: 2600,
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
            humidityOffset: ruuviTag.offsetHumidity.map { $0 / 100 },
            pressureOffset: ruuviTag.offsetPressure.map { $0 / 100 }
        )
    }
}
