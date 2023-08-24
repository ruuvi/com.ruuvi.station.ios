import Foundation

public struct NFCSensor: Sensor {
    public var id: String
    public var macId: String
    public var firmwareVersion: String

    public init(id: String, macId: String, firmwareVersion: String) {
        self.id = id
        self.macId = macId
        self.firmwareVersion = firmwareVersion
    }
}
