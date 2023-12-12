import FirebaseRemoteConfig
import Foundation

public final class FirebaseFeatureToggleProvider: FeatureToggleProvider {
    var remoteConfigService: RemoteConfigService!

    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        remoteConfigService.synchronize { [weak self] result in
            guard let sSelf = self else { return }
            switch result {
            case .success:
                let remoteConfig = sSelf.remoteConfigService.remoteConfig
                let keys = remoteConfig.allKeys(from: .remote)
                let featureToggles: [FeatureToggle] = keys.compactMap {
                    if let feature = Feature(rawValue: $0) {
                        FeatureToggle(
                            feature: feature,
                            enabled: remoteConfig[$0].boolValue,
                            source: .remote
                        )
                    } else {
                        nil
                    }
                }
                completion(featureToggles)
            case let .failure(error):
                print(error.localizedDescription)
                completion([])
            }
        }
    }
}
