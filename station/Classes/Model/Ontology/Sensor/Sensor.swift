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

protocol Networkable {
    var networkProvider: RuuviNetworkProvider? { get }
    var isClaimed: Bool { get }
    var isOwner: Bool { get }
}

protocol Sensor: StringIdentifieable {}

protocol PhysicalSensor: Sensor, Connectable, Nameable {
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
}

protocol VirtualSensor: Sensor, Nameable {}

protocol LocationVirtualSensor: VirtualSensor, Locateable {}
