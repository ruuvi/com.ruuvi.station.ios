import Foundation

extension RuuviTagSensorRecord {
    var measurement: RuuviMeasurement {
        return RuuviMeasurement(ruuviTagId: id,
                                measurementSequenceNumber: measurementSequenceNumber,
                                date: date,
                                rssi: rssi,
                                temperature: temperature,
                                humidity: humidity,
                                pressure: pressure,
                                acceleration: acceleration,
                                voltage: voltage,
                                movementCounter: movementCounter,
                                txPower: txPower)
    }
}
