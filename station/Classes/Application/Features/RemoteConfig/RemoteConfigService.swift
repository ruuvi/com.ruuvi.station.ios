import Foundation
import FirebaseRemoteConfig

protocol RemoteConfigService {
    var remoteConfig: RemoteConfig { get }
    func synchronize(completion: ((Result<Bool, Error>) -> Void)?)
}
