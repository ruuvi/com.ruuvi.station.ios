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
    var firmwareVersion: String? { get }
}

public protocol Locateable {
    var loc: Location? { get }
}

public protocol Claimable {
    var isClaimed: Bool { get }
    var isOwner: Bool { get }
    var owner: String? { get }
    var isCloudSensor: Bool? { get }
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

public protocol CloudSensor: Sensor, Nameable, Claimable, HasRemotePicture, Calibratable, Shareable {}

public protocol Shareable {
    var canShare: Bool { get }
    var sharedTo: [String] { get } // emails
}

public protocol ShareableSensor: Sensor, Shareable {}
