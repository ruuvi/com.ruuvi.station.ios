import Foundation

public final class FeatureToggleService {
    private init() { }
    static let shared = FeatureToggleService()

    private var featureToggles: [FeatureToggle] = []

    public func fetchFeatureToggles(
        mainProvider: FeatureToggleProvider,
        fallbackProvider: FeatureToggleProvider?,
        completion: @escaping ([FeatureToggle]) -> Void
    ) {
        mainProvider.fetchFeatureToggles { [weak self] fetchedFeatureToggles in
            guard let sSelf = self else { return }

            if fetchedFeatureToggles.count > 0 {
                sSelf.featureToggles = fetchedFeatureToggles
            } else if let fallbackProvider = fallbackProvider {
                sSelf.useFallbackFeatureToggles(fallbackProvider)
            }

            completion(sSelf.featureToggles)
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
