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
            version: 0,
            temperature: unitTemperature,
            humidity: unitHumidity,
            pressure: unitPressure,
            acceleration: acceleration,
            voltage: unitVoltage,
            movementCounter: nil,
            measurementSequenceNumber: nil,
            txPower: nil,
            // TODO: Add support for log (E0_F0 FW)
            pm1: nil,
            pm2_5: nil,
            pm4: nil,
            pm10: nil,
            co2: nil,
            voc: nil,
            nox: nil,
            luminance: nil,
            dbaAvg: nil,
            dbaPeak: nil,
            temperatureOffset: 0.0,
            humidityOffset: 0.0,
            pressureOffset: 0.0
        )
    }
}
