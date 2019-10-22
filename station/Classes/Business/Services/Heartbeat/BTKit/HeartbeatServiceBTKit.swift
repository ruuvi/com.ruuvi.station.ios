import Foundation
import Future
import BTKit

class HeartbeatServiceBTKit: HeartbeatService {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    var connection: BTConnection!
    
    func startKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: true, of: ruuviTag)
    }
    
    func stopKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: false, of: ruuviTag)
    }
}
