import Foundation

protocol RuuviTagSensor: PhysicalSensor, Versionable { }

extension RuuviTagSensor {
    var id: String {
        if let macId = macId {
            return macId.value
        } else if let luid = luid {
            return luid.value
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
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(version: Int) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(macId: MACIdentifier) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name)
    }

    func with(isConnectable: Bool) -> RuuviTagSensor {
        return RuuviTagSensorStruct(version: version,
                                    luid: luid,
                                    macId: macId,
                                    isConnectable: isConnectable,
                                    name: name)
    }
}

struct RuuviTagSensorStruct: RuuviTagSensor {
    var version: Int
    var luid: LocalIdentifier? // local unqiue id
    var macId: MACIdentifier?
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
    var luid: LocalIdentifier? {
        return object.luid
    }
    var macId: MACIdentifier? {
        return object.macId
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
