import Foundation

protocol RuuviTagSensor: PhysicalSensor, Versionable { }

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

    var any: AnyRuuviTagSensor {
        return AnyRuuviTagSensor(object: self)
    }

    var `struct`: RuuviTagSensorStruct {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    mac: mac,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(version: Int) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    mac: mac,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(mac: String) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    mac: mac,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(isConnectable: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    mac: mac,
                                    isConnectable: isConnectable,
                                    name: name)
    }
}

struct RuuviTagSensorStruct: RuuviTagSensor {
    var version: Int
    var luid: String? // local unqiue id
    var mac: String?
    var isConnectable: Bool
    var name: String
}

struct AnyRuuviTagSensor: RuuviTagSensor, Equatable, Hashable {
    var object: RuuviTagSensor

    var id: String {
        return object.id
    }
    var version: Int {
        return object.version
    }
    var luid: String? {
        return object.luid
    }
    var mac: String? {
        return object.mac
    }
    var isConnectable: Bool {
        return object.isConnectable
    }
    var name: String {
        return object.name
    }

    static func == (lhs: AnyRuuviTagSensor, rhs: AnyRuuviTagSensor) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
