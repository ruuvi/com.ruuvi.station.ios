import Foundation

public final class FeatureToggleService {
    public var source: FeatureSource {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: sourceUDKey) {
                return FeatureSource(rawValue: rawValue) ?? .remote
            } else {
                return .remote
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sourceUDKey)
        }
    }

    var firebaseProvider: FeatureToggleProvider!
    var fallbackProvider: FeatureToggleProvider!
    var localProvider: FeatureToggleProvider!

    private var remoteToggles: [FeatureToggle] = []
    private var localToggles: [FeatureToggle] = []
    private let sourceUDKey = "FeatureToggleService.sourceUDKey"

    public func fetchFeatureToggles() {
        firebaseProvider.fetchFeatureToggles { [weak self] fetchedFeatureToggles in
            guard let sSelf = self else { return }

            if fetchedFeatureToggles.count > 0 {
                sSelf.remoteToggles = fetchedFeatureToggles
            } else {
                sSelf.useFallbackFeatureToggles(sSelf.fallbackProvider)
            }
        }
        localProvider.fetchFeatureToggles { [weak self] fetchedFeatureToggles in
            guard let sSelf = self else { return }
            sSelf.localToggles = fetchedFeatureToggles
        }
    }
    public func isEnabled(_ feature: Feature) -> Bool {
        switch source {
        case .remote:
            let toggle = remoteToggles.first(where: { $0.feature == feature })
            return toggle?.enabled ?? false
        case .local:
            let toggle = localToggles.first(where: { $0.feature == feature })
            return toggle?.enabled ?? false
        }

    }

    private func useFallbackFeatureToggles(_ fallbackProvider: FeatureToggleProvider) {
        fallbackProvider.fetchFeatureToggles { [weak self] featureToggles in
            if let sSelf = self {
                sSelf.remoteToggles = featureToggles
            }
        }
    }
}
