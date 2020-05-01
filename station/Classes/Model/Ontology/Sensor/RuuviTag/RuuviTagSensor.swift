import Foundation

protocol RuuviTagSensor: Sensor {
    var version: Int { get }
}

extension RuuviTagSensor {
    var id: String {
        if let mac = mac {
            return mac
        } else if let uuid = uuid {
            return uuid
        } else {
            fatalError()
        }
    }
}
