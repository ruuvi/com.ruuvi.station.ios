import Foundation

public protocol StringIdentifieable: Sendable {
    var id: String { get }
}

public protocol BackgroundScanable: Sendable {
    var serviceUUID: String? { get }
}

public protocol Connectable: Sendable {
    var isConnectable: Bool { get }
}

public protocol Nameable: Sendable {
    var name: String { get }
}

public protocol Versionable: Sendable {
    var version: Int { get }
    var firmwareVersion: String? { get }
}

public protocol Locateable: Sendable {
    var loc: Location? { get }
}

public protocol Claimable: Sendable {
    var isClaimed: Bool { get }
    var isOwner: Bool { get }
    var owner: String? { get }
    var isCloudSensor: Bool? { get }
    var ownersPlan: String? { get }
}

public protocol Sensor: StringIdentifieable {}

public protocol HasRemotePicture: Sendable {
    var picture: URL? { get }
}

public protocol Calibratable: Sendable {
    var offsetTemperature: Double? { get } // in degrees
    var offsetHumidity: Double? { get } // in fraction of one
    var offsetPressure: Double? { get } // in hPa
}

public protocol CloudSensor: Sensor,
                             Nameable,
                             Claimable,
                             HasRemotePicture,
                             Calibratable,
                             Shareable,
                             HistoryFetchable,
                             BackgroundScanable {}

public protocol Shareable: Sendable {
    var canShare: Bool { get }
    var sharedTo: [String] { get } // emails
}

public protocol HistoryFetchable: Sendable {
    var maxHistoryDays: Int? { get }
}

public protocol ShareableSensor: Sensor, Shareable {}
