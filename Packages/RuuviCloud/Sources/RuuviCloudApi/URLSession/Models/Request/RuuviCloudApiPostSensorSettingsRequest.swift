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

    public var individualRequests: [Self] {
        guard type.count == value.count else { return [] }
        return zip(type, value).map { setting, value in
            Self(sensor: sensor, type: [setting], value: [value], timestamp: timestamp)
        }
    }

    public var queueKey: String {
        let key = "\(sensor)-sensor-settings-\(type.joined(separator: ","))"
        let offsets: Set<String> = [
            RuuviCloudApiSetting.sensorOffsetTemperature.rawValue,
            RuuviCloudApiSetting.sensorOffsetHumidity.rawValue,
            RuuviCloudApiSetting.sensorOffsetPressure.rawValue,
        ]
        guard type.contains(where: offsets.contains) else { return key }
        // The backend rejects older offset retries by their original timestamp.
        return "\(key)-\(timestamp.map(String.init) ?? "legacy")"
    }
}
