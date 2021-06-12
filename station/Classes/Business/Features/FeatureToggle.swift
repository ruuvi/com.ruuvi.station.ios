import Foundation

public enum Feature: String, CaseIterable, Decodable {
    case network = "ios_network"
    case updateFirmware = "ios_update_firmware"
    case syncZoom = "ios_sync_zoom"
    case dpahAlerts = "ios_dp_ah_alerts"
}

public enum FeatureSource: String, Decodable {
    case remote
    case local
}

public struct FeatureToggle {
    let feature: Feature
    let enabled: Bool
    let source: FeatureSource
}

extension FeatureToggle: Decodable {
    enum CodingKeys: String, CodingKey {
        case feature
        case enabled
        case source
    }
}
