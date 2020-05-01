import Foundation

protocol Device {
    var id: String { get }
}

protocol Connectable {
    var isConnectable: Bool { get }
}

protocol Nameable {
    var name: String { get }
}

protocol Sensor: Device, Connectable, Nameable {
    var uuid: String? { get }
    var mac: String? { get }
}
