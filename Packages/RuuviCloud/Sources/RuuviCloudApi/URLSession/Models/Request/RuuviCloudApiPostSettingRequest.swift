import Foundation

struct RuuviCloudApiPostSettingRequest: Encodable {
    let name: RuuviCloudApiSetting
    let value: String
}
