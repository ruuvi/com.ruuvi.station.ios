import Foundation

public struct RuuviCloudApiPostSettingRequest: Encodable {
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
