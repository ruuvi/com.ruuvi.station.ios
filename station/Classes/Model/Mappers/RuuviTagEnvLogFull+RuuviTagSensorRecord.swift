import BTKit
import Humidity

extension RuuviTagEnvLogFull {

    var unitTemperature: Temperature? {
        return Temperature(value: temperature, unit: .celsius)
    }
    var unitHumidity: Humidity? {
        return Humidity(c: temperature, rh: humidity / 100.0)
    }
    var unitPressure: Pressure? {
        return Pressure(value: pressure, unit: .hectopascals)
    }
    var acceleration: Acceleration? {
        return nil
    }
    var unitVoltage: Voltage? {
        return nil
    }

    func ruuviSensorRecord(uuid: String, mac: String?) -> RuuviTagSensorRecord {
        return RuuviTagSensorRecordStruct(ruuviTagId: mac ?? uuid,
                                          date: date,
                                          mac: mac,
                                          rssi: nil,
                                          temperature: unitTemperature,
                                          humidity: unitHumidity,
                                          pressure: unitPressure,
                                          acceleration: acceleration,
                                          voltage: unitVoltage,
                                          movementCounter: nil,
                                          measurementSequenceNumber: nil,
                                          txPower: nil)
    }
}
