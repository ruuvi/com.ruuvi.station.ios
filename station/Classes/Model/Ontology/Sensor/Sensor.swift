import Foundation

protocol StringIdentifieable {
    var id: String { get }
}

protocol Connectable {
    var isConnectable: Bool { get }
}

protocol Nameable {
    var name: String { get }
}

protocol Versionable {
    var version: Int { get }
}

protocol Locateable {
    var location: Location { get }
}

protocol Sensor: StringIdentifieable {}

protocol PhysicalSensor: Sensor, Connectable, Nameable {
    var luid: LocalIdentifier? { get }
    var mac: String? { get }
}

protocol Identifier {
    var value: String { get }
}

protocol LocalIdentifier: Identifier {
}

protocol MACIdentifier: Identifier {

}

protocol VirtualSensor: Sensor, Nameable {}

protocol LocationVirtualSensor: VirtualSensor, Locateable {}

struct LocalIdentifierStruct: LocalIdentifier {
    var value: String
}

struct AnyLocalIdentifier: LocalIdentifier, Equatable, Hashable {
    var object: LocalIdentifier

    var value: String {
        return object.value
    }

    static func == (lhs: AnyLocalIdentifier, rhs: AnyLocalIdentifier) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

extension String {
    var luid: LocalIdentifier {
        return LocalIdentifierStruct(value: self).any
    }
}

extension LocalIdentifier {
    var any: AnyLocalIdentifier {
        return AnyLocalIdentifier(object: self)
    }
}
