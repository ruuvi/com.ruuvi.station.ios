import Foundation

public struct RuuviCloudApiPostSettingRequest: Codable {
    let name: RuuviCloudApiSetting
    let value: String

    public init(
        name: RuuviCloudApiSetting,
        value: String
    ) {
        self.name = name
        self.value = value
    }
}
