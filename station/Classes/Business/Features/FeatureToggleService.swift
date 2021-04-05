import Foundation

public final class FeatureToggleService {
    var mainProvider: FeatureToggleProvider!
    var fallbackProvider: FeatureToggleProvider!

    private var featureToggles: [FeatureToggle] = []

    public func fetchFeatureToggles(completion: (([FeatureToggle]) -> Void)? = nil) {
        mainProvider.fetchFeatureToggles { [weak self] fetchedFeatureToggles in
            guard let sSelf = self else { return }

            if fetchedFeatureToggles.count > 0 {
                sSelf.featureToggles = fetchedFeatureToggles
            } else {
                sSelf.useFallbackFeatureToggles(sSelf.fallbackProvider)
            }

            completion?(sSelf.featureToggles)
        }
    }
    public func isEnabled(_ feature: Feature) -> Bool {
        let feature = featureToggles.first(where: { $0.feature == feature })
        return feature?.enabled ?? false
    }

    private func useFallbackFeatureToggles(_ fallbackProvider: FeatureToggleProvider) {
        fallbackProvider.fetchFeatureToggles { [weak self] featureToggles in
            if let sSelf = self {
                sSelf.featureToggles = featureToggles
            }
        }
    }
}
