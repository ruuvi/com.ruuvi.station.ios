import Foundation

public protocol VirtualTagSensor: VirtualSensor, Nameable, Locateable { }

extension VirtualTagSensor {
    public var any: AnyVirtualTagSensor {
        return AnyVirtualTagSensor(object: self)
    }

    public var `struct`: VirtualTagSensorStruct {
        return VirtualTagSensorStruct(
            id: id,
            name: name,
            loc: loc
        )
    }

}

public struct VirtualTagSensorStruct: VirtualTagSensor {
    public var id: String
    public var name: String
    public var loc: Location?

    public init(
        id: String,
        name: String,
        loc: Location?
    ) {
        self.id = id
        self.name = name
        self.loc = loc
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

    public var loc: Location? {
        return object.loc
    }

    public static func == (lhs: AnyVirtualTagSensor, rhs: AnyVirtualTagSensor) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
