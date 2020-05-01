import Foundation
import Humidity

struct RuuviMeasurement: RuuviTagSensorRecord {
    var ruuviTagId: String
    var measurementSequenceNumber: Int?
    var date: Date
    var rssi: Int?
    var temperature: Temperature?
    var humidity: Humidity?
    var pressure: Pressure?
    // v3 & v5
    var acceleration: Acceleration?
    var voltage: Voltage?
    // v5
    var movementCounter: Int?
    var txPower: Int?
}
