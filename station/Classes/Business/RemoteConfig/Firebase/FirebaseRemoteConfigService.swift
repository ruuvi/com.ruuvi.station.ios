import Foundation
import FirebaseRemoteConfig

final class FirebaseRemoteConfigService: RemoteConfigService {
    let remoteConfig = RemoteConfig.remoteConfig()

    func synchronize(completion: ((Result<Bool, Error>) -> Void)?) {
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings
        remoteConfig.fetchAndActivate { status, error in
            switch status {
            case .successFetchedFromRemote, .successUsingPreFetchedData:
                completion?(.success(true))
            case .error:
                if let error = error {
                    completion?(.failure(error))
                } else {
                    completion?(.success(false))
                }
            @unknown default:
                assertionFailure()
                completion?(.success(false))
            }
        }
    }
}
