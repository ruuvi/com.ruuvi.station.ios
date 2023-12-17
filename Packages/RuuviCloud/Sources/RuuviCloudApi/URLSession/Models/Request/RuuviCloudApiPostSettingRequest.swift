import Foundation

public struct RuuviCloudApiPostSettingRequest: Codable {
    let name: RuuviCloudApiSetting
    let value: String?
    let timestamp: Int?

    public init(
        name: RuuviCloudApiSetting,
        value: String?,
        timestamp: Int?
    ) {
        self.name = name
        self.value = value
        self.timestamp = timestamp
    }
}
