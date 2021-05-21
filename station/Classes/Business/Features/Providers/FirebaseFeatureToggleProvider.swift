import Foundation
import FirebaseRemoteConfig

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
                        return FeatureToggle(
                            feature: feature,
                            enabled: remoteConfig[$0].boolValue,
                            source: .remote
                        )
                    } else {
                        return nil
                    }
                }
                completion(featureToggles)
            case .failure(let error):
                print(error.localizedDescription)
                completion([])
            }
        }

    }
}
