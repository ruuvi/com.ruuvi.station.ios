import Foundation
import FirebaseRemoteConfig

public struct FirebaseRemoteConfigProvider: FeatureToggleProvider {
    public func fetchFeatureToggles(_ completion: @escaping FeatureToggleCallback) {
        let remoteConfig = RemoteConfig.remoteConfig()
        let keys = remoteConfig.allKeys(from: .remote)
        let featureToggles = keys.map {
            FeatureToggle(feature: Feature(rawValue: $0), enabled: remoteConfig[$0].boolValue)
        }

        completion(featureToggles)
    }
}
