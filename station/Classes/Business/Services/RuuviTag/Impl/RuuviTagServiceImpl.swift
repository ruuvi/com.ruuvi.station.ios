import Foundation
import Future
import BTKit

class RuuviTagServiceImpl: RuuviTagService {
    var ruuviTagPersistence: RuuviTagPersistence!
    var calibrationService: CalibrationService!
    var backgroundPersistence: BackgroundPersistence!
    var connectionPersistence: ConnectionPersistence!

    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        backgroundPersistence.deleteCustomBackground(for: ruuviTag.uuid)
        connectionPersistence.setKeepConnection(false, for: ruuviTag.uuid)
        return ruuviTagPersistence.delete(ruuviTag: ruuviTag)
    }

    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        return ruuviTagPersistence.update(name: name, of: ruuviTag)
    }
}
