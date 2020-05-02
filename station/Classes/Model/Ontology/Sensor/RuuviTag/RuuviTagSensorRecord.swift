import Foundation
import Humidity

protocol RuuviTagSensorRecord {
    var ruuviTagId: String { get set }
    var date: Date { get set }
    var mac: String? { get set }
    var rssi: Int? { get set }
    var temperature: Temperature? { get set }
    var humidity: Humidity? { get set }
    var pressure: Pressure? { get set }
    // v3 & v5
    var acceleration: Acceleration? { get set }
    var voltage: Voltage? { get set }
    // v5
    var movementCounter: Int? { get set }
    var measurementSequenceNumber: Int? { get set }
    var txPower: Int? { get set }
}

extension RuuviTagSensorRecord {
    var id: String {
        return ruuviTagId + "\(date.timeIntervalSince1970)"
    }
}
