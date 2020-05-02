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

protocol Device: StringIdentifieable {}

protocol Sensor: Device, Connectable, Nameable {
    var luid: String? { get }
    var mac: String? { get }
}
