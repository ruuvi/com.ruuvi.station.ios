import Foundation

protocol RuuviTagSensor: Sensor, Versionable { }

extension RuuviTagSensor {
    var id: String {
        if let mac = mac {
            return mac
        } else if let luid = luid {
            return luid
        } else {
            fatalError()
        }
    }
}

struct RuuviTagSensorStruct: RuuviTagSensor {
    var version: Int
    var luid: String? // local unqiue id
    var mac: String?
    var isConnectable: Bool
    var name: String
}
