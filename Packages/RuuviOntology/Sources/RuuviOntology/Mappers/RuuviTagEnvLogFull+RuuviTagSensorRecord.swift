import BTKit
import Humidity

extension RuuviTagEnvLogFull {
    var unitTemperature: Temperature? {
        Temperature(value: temperature, unit: .celsius)
    }

    var unitHumidity: Humidity? {
        let relativeHumidity = humidity / 100.0
        guard relativeHumidity >= 0 else { return nil }
        return Humidity(
            relative: relativeHumidity,
            temperature: unitTemperature
        )
    }

    var unitPressure: Pressure? {
        Pressure(value: pressure, unit: .hectopascals)
    }

    var acceleration: Acceleration? {
        nil
    }

    var unitVoltage: Voltage? {
        nil
    }

    public func ruuviSensorRecord(uuid: String, mac: String?) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: uuid.luid,
            date: date,
            source: .log,
            macId: mac?.mac,
            rssi: nil,
            temperature: unitTemperature,
            humidity: unitHumidity,
            pressure: unitPressure,
            acceleration: acceleration,
            voltage: unitVoltage,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            temperatureOffset: 0.0,
            humidityOffset: 0.0,
            pressureOffset: 0.0
        )
    }
}
