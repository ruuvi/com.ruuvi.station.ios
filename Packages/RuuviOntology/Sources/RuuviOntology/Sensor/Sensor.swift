import Foundation

public protocol StringIdentifieable {
    var id: String { get }
}

public protocol Connectable {
    var isConnectable: Bool { get }
}

public protocol Nameable {
    var name: String { get }
}

public protocol Versionable {
    var version: Int { get }
}

public protocol Locateable {
    var location: Location { get }
}

public protocol Networkable {
    var isClaimed: Bool { get }
    var isOwner: Bool { get }
    var owner: String? { get }
}

public protocol Sensor: StringIdentifieable {}

public protocol CloudSensor: Sensor, Nameable, Networkable {
}

public protocol PhysicalSensor: Sensor, Connectable, Nameable {
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
}

public protocol VirtualSensor: Sensor, Nameable {}

public protocol LocationVirtualSensor: VirtualSensor, Locateable {}
