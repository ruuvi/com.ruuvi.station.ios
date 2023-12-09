import Foundation

public final class FeatureToggleService {
    public var source: FeatureSource {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: sourceUDKey) {
                FeatureSource(rawValue: rawValue) ?? .remote
            } else {
                .remote
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sourceUDKey)
        }
    }

    var firebaseProvider: FeatureToggleProvider!
    var fallbackProvider: FeatureToggleProvider!
    var localProvider: LocalFeatureToggleProvider!

    private var remoteToggles: [FeatureToggle] {
        get {
            if let storedRemoteToggles = UserDefaults.standard.object(forKey: remoteTogglesUDKey) as? Data,
               let toggles = try? JSONDecoder().decode([FeatureToggle].self, from: storedRemoteToggles)
            {
                toggles
            } else {
                []
            }
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: remoteTogglesUDKey)
            }
        }
    }

    private var localToggles: [FeatureToggle] = []
    private let sourceUDKey = "FeatureToggleService.sourceUDKey"
    private let remoteTogglesUDKey = "FeatureToggleService.remoteTogglesUDKey"

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

    public func enableLocal(_ feature: Feature) {
        if let toggleIndex = localToggles.firstIndex(where: { $0.feature == feature }) {
            let toggle = localToggles[toggleIndex]
            assert(toggle.source == .local)
            localProvider.enable(toggle)
            localToggles[toggleIndex] = FeatureToggle(feature: toggle.feature, enabled: true, source: toggle.source)
        } else {
            assertionFailure()
        }
    }

    public func disableLocal(_ feature: Feature) {
        if let toggleIndex = localToggles.firstIndex(where: { $0.feature == feature }) {
            let toggle = localToggles[toggleIndex]
            assert(toggle.source == .local)
            localProvider.disable(toggle)
            localToggles[toggleIndex] = FeatureToggle(feature: toggle.feature, enabled: false, source: toggle.source)
        } else {
            assertionFailure()
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
