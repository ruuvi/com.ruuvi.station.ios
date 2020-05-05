import Foundation

protocol VirtualTagSensor: VirtualSensor { }

extension VirtualTagSensor {
    var any: AnyVirtualTagSensor {
        return AnyVirtualTagSensor(object: self)
    }

    var `struct`: VirtualTagSensorStruct {
        return VirtualTagSensorStruct(id: id, name: name)
    }

}

struct VirtualTagSensorStruct: VirtualTagSensor {
    var id: String
    var name: String
}

struct AnyVirtualTagSensor: VirtualTagSensor, Equatable, Hashable {
    var object: VirtualTagSensor

    var id: String {
        return object.id
    }

    var name: String {
        return object.name
    }

    static func == (lhs: AnyVirtualTagSensor, rhs: AnyVirtualTagSensor) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
