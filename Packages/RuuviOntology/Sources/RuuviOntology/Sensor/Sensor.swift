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

public protocol Claimable {
    var isClaimed: Bool { get }
    var isOwner: Bool { get }
    var owner: String? { get }
}

public protocol Sensor: StringIdentifieable {}

public protocol HasRemotePicture {
    var picture: URL? { get }
}

public protocol Calibratable {
    var offsetTemperature: Double? { get } // in degrees
    var offsetHumidity: Double? { get } // in fraction of one
    var offsetPressure: Double? { get } // in hPa
}

public protocol CloudSensor: Sensor, Nameable, Claimable, HasRemotePicture, Calibratable {
}

public protocol Shareable {
    var sharedTo: [String] { get } // emails
}

public protocol ShareableSensor: Sensor, Shareable {
}

public protocol PhysicalSensor: Sensor, Connectable, Nameable {
    var luid: LocalIdentifier? { get }
    var macId: MACIdentifier? { get }
}

public protocol VirtualSensor: Sensor, Nameable {}

public protocol LocationVirtualSensor: VirtualSensor, Locateable {}
