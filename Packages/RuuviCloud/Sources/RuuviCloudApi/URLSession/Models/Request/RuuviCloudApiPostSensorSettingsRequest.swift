import Foundation

public struct RuuviCloudApiPostSensorSettingsRequest: Codable {
    public let sensor: String
    public let type: [String]
    public let value: [String]
    public let timestamp: Int?

    public init(
        sensor: String,
        type: [String],
        value: [String],
        timestamp: Int?
    ) {
        self.sensor = sensor
        self.type = type
        self.value = value
        self.timestamp = timestamp
    }
}
