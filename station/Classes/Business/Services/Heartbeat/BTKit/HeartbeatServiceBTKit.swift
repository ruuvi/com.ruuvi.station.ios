import Foundation
import Future

class HeartbeatServiceBTKit: HeartbeatService {
    
    var ruuviTagPersistence: RuuviTagPersistence!
    
    func startKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: true, of: ruuviTag)
    }
    
    func stopKeepingConnection(to ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(keepConnection: false, of: ruuviTag)
    }
}
