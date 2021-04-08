import Foundation

public final class LocalFeatureToggleProvider: FeatureToggleProvider {
    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        let featureToggles: [FeatureToggle] = Feature.allCases.map { feature in
            let isEnabled = UserDefaults.standard.bool(forKey: isEnabledPrefix + feature.rawValue)
            return FeatureToggle(feature: feature, enabled: isEnabled, source: .local)
        }
        completion(featureToggles)
    }

    private let isEnabledPrefix = "LocalFeatureToggleProvider.isEnabledPrefix"
}
