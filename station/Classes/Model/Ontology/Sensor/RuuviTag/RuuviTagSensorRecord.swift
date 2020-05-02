import Foundation
import Humidity

protocol RuuviTagSensorRecord {
    var ruuviTagId: String { get }
    var date: Date { get }
    var mac: String? { get }
    var rssi: Int? { get }
    var temperature: Temperature? { get }
    var humidity: Humidity? { get }
    var pressure: Pressure? { get }
    // v3 & v5
    var acceleration: Acceleration? { get }
    var voltage: Voltage? { get }
    // v5
    var movementCounter: Int? { get }
    var measurementSequenceNumber: Int? { get }
    var txPower: Int? { get }
}

extension RuuviTagSensorRecord {
    var id: String {
        return ruuviTagId + "\(date.timeIntervalSince1970)"
    }
}

struct RuuviTagSensorRecordStuct: RuuviTagSensorRecord {
    var ruuviTagId: String
    var date: Date
    var mac: String?
    var rssi: Int?
    var temperature: Temperature?
    var humidity: Humidity?
    var pressure: Pressure?
    // v3 & v5
    var acceleration: Acceleration?
    var voltage: Voltage?
    // v5
    var movementCounter: Int?
    var measurementSequenceNumber: Int?
    var txPower: Int?
}
