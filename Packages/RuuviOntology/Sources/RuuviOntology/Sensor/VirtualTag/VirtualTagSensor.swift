import Foundation

public protocol VirtualTagSensor: VirtualSensor, Nameable { }

extension VirtualTagSensor {
    public var any: AnyVirtualTagSensor {
        return AnyVirtualTagSensor(object: self)
    }

    public var `struct`: VirtualTagSensorStruct {
        return VirtualTagSensorStruct(id: id, name: name)
    }

}

public struct VirtualTagSensorStruct: VirtualTagSensor {
    public var id: String
    public var name: String

    public init(
        id: String,
        name: String
    ) {
        self.id = id
        self.name = name
    }
}

public struct AnyVirtualTagSensor: VirtualTagSensor, Equatable, Hashable {
    var object: VirtualTagSensor

    public var id: String {
        return object.id
    }

    public var name: String {
        return object.name
    }

    public static func == (lhs: AnyVirtualTagSensor, rhs: AnyVirtualTagSensor) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
