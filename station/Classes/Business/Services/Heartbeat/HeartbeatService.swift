import Foundation
import Future

protocol HeartbeatService {
    func startKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func stopKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
}
