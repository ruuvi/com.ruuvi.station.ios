import Foundation
import Future

protocol HeartbeatService {
    func start()
    func stop()
    func startKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func stopKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
}
