import Foundation
import BTKit
import Future

class RuuviTagServiceImpl: RuuviTagService {
    var ruuviTagPersistence: RuuviTagPersistence!
    var calibrationService: CalibrationService!
    var backgroundPersistence: BackgroundPersistence!
    
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError> {
        let offsetData = calibrationService.humidityOffset(for: ruuviTag.uuid)
        return ruuviTagPersistence.persist(ruuviTag: ruuviTag, name: name, humidityOffset: offsetData.0, humidityOffsetDate: offsetData.1)
    }
    
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        backgroundPersistence.deleteCustomBackground(for: ruuviTag.uuid)
        return ruuviTagPersistence.delete(ruuviTag: ruuviTag)
    }
    
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        return ruuviTagPersistence.update(name: name, of: ruuviTag)
    }
}
