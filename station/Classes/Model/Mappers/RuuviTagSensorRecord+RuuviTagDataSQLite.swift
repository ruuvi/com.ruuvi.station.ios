import Foundation

extension RuuviTagSensorRecord {
    var sqlite: RuuviTagDataSQLite {
        return RuuviTagDataSQLite(ruuviTagId: ruuviTagId,
                                  date: date,
                                  mac: mac,
                                  rssi: rssi,
                                  temperature: temperature,
                                  humidity: humidity,
                                  pressure: pressure,
                                  acceleration: acceleration,
                                  voltage: voltage,
                                  movementCounter: movementCounter,
                                  measurementSequenceNumber: measurementSequenceNumber,
                                  txPower: txPower)
    }
}
