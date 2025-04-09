import BTKit
import Humidity

extension RuuviTagEnvLogFull {
    var unitTemperature: Temperature? {
        guard let temperature = temperature else { return nil }
        return Temperature(value: temperature, unit: .celsius)
    }

    var unitHumidity: Humidity? {
        guard let humidity = humidity else { return nil }
        let relativeHumidity = humidity / 100.0
        guard relativeHumidity >= 0 else { return nil }
        return Humidity(
            relative: relativeHumidity,
            temperature: unitTemperature
        )
    }

    var unitPressure: Pressure? {
        guard let pressure = pressure else { return nil }
        return Pressure(value: pressure, unit: .hectopascals)
    }

    var acceleration: Acceleration? {
        nil
    }

    var unitVoltage: Voltage? {
        Voltage(value: batteryVoltage ?? 0, unit: .volts)
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
            pm1: pm1,
            pm2_5: pm25,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminosity,
            dbaAvg: soundAvg,
            dbaPeak: soundPeak,
            temperatureOffset: 0.0,
            humidityOffset: 0.0,
            pressureOffset: 0.0
        )
    }
}
