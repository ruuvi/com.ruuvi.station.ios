import Foundation
import Future
import BTKit

class RuuviTagServiceImpl: RuuviTagService {
    var ruuviTagPersistence: RuuviTagPersistence!
    var calibrationService: CalibrationService!
    var backgroundPersistence: BackgroundPersistence!
    var connectionPersistence: ConnectionPersistence!

    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag, RUError> {
        let offsetData = calibrationService.humidityOffset(for: ruuviTag.uuid)
        return ruuviTagPersistence.persist(ruuviTag: ruuviTag,
                                           name: name,
                                           humidityOffset: offsetData.0,
                                           humidityOffsetDate: offsetData.1)
    }

    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        backgroundPersistence.deleteCustomBackground(for: ruuviTag.uuid)
        connectionPersistence.setKeepConnection(false, for: ruuviTag.uuid)
        connectionPersistence.setLogSyncDate(nil, uuid: ruuviTag.uuid)
        return ruuviTagPersistence.delete(ruuviTag: ruuviTag)
    }

    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        return ruuviTagPersistence.update(name: name, of: ruuviTag)
    }

    func clearHistory(uuid: String) -> Future<Bool, RUError> {
        connectionPersistence.setLogSyncDate(nil, uuid: uuid)
        return ruuviTagPersistence.clearHistory(uuid: uuid)
    }
}
