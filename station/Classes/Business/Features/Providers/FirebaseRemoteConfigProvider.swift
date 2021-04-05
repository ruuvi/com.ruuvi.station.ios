import Foundation
import FirebaseRemoteConfig

public final class FirebaseRemoteConfigProvider: FeatureToggleProvider {
    var remoteConfigService: RemoteConfigService!

    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        remoteConfigService.synchronize { [weak self] result in
            guard let sSelf = self else { return }
            switch result {
            case .success:
                let remoteConfig = sSelf.remoteConfigService.remoteConfig
                let keys = remoteConfig.allKeys(from: .remote)
                let featureToggles = keys.map {
                    FeatureToggle(feature: Feature(rawValue: $0), enabled: remoteConfig[$0].boolValue)
                }
                completion(featureToggles)
            case .failure(let error):
                print(error.localizedDescription)
                assertionFailure("Failed to synchronize RemoteConfig")
                completion([])
            }
        }

    }
}
