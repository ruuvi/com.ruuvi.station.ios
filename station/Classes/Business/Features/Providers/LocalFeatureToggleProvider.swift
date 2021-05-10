import Foundation

public final class LocalFeatureToggleProvider: FeatureToggleProvider {
    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        let featureToggles: [FeatureToggle] = Feature.allCases.map { feature in
            let isEnabled = UserDefaults.standard.bool(forKey: isEnabledPrefix + feature.rawValue)
            return FeatureToggle(feature: feature, enabled: isEnabled, source: .local)
        }
        completion(featureToggles)
    }

    public func enable(_ featureToggle: FeatureToggle) {
        guard featureToggle.source == .local else { assertionFailure(); return }
        UserDefaults.standard.setValue(true, forKey: isEnabledPrefix + featureToggle.feature.rawValue)
    }

    public func disable(_ featureToggle: FeatureToggle) {
        guard featureToggle.source == .local else { assertionFailure(); return }
        UserDefaults.standard.setValue(false, forKey: isEnabledPrefix + featureToggle.feature.rawValue)
    }

    private let isEnabledPrefix = "LocalFeatureToggleProvider.isEnabledPrefix"
}
