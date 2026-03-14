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
            temperature: Temperature(54.20),
            humidity: Humidity(relative: 0.332, temperature: Temperature(54.20)),
            pressure: Pressure(1009.60),
            acceleration: nil,
            voltage: nil,
            movementCounter: 8,
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
            date: Date().addingTimeInterval(-120),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(21.30),
            humidity: Humidity(relative: 0.458, temperature: Temperature(21.30)),
            pressure: Pressure(1015.10),
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
            date: Date().addingTimeInterval(-300),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 5,
            temperature: Temperature(18.70),
            humidity: Humidity(relative: 0.521, temperature: Temperature(18.70)),
            pressure: Pressure(1012.80),
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

    static func previewOffice() -> RuuviTagSensorRecordStruct {
        RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-540),
            source: .ruuviNetwork,
            macId: nil,
            rssi: -61,
            version: 5,
            temperature: Temperature(22.40),
            humidity: Humidity(relative: 0.416, temperature: Temperature(22.40)),
            pressure: Pressure(1011.80),
            acceleration: nil,
            voltage: Voltage(value: 2.95, unit: .volts),
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

    static func previewAirC044() -> RuuviTagSensorRecordStruct {
        let temperature = Temperature(21.20)
        return RuuviTagSensorRecordStruct(
            luid: nil,
            date: Date().addingTimeInterval(-45),
            source: .ruuviNetwork,
            macId: nil,
            rssi: nil,
            version: 6,
            temperature: temperature,
            humidity: Humidity(relative: 0.435, temperature: temperature),
            pressure: Pressure(1008.80),
            acceleration: nil,
            voltage: nil,
            movementCounter: nil,
            measurementSequenceNumber: 3124,
            txPower: nil,
            pm1: 0,
            pm25: 0,
            pm4: 0,
            pm10: 0,
            co2: 640,
            voc: 95,
            nox: 1,
            luminance: 1800,
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
