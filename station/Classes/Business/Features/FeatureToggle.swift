import Foundation

public struct FeatureToggle {
    let feature: Feature
    let enabled: Bool
}

extension FeatureToggle: Decodable {
    enum CodingKeys: String, CodingKey {
        case feature
        case enabled
    }
}
