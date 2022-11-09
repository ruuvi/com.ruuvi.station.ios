import Foundation

public enum Feature: String, CaseIterable, Codable {
    case legacyFirmwareUpdatePopup = "ios_legacy_fw_update_dialog"
}

public enum FeatureSource: String, Codable {
    case remote
    case local
}

public struct FeatureToggle {
    let feature: Feature
    let enabled: Bool
    let source: FeatureSource
}

extension FeatureToggle: Codable {
    enum CodingKeys: String, CodingKey {
        case feature
        case enabled
        case source
    }
}
