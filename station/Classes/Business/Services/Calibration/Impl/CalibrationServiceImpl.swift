import Foundation
import Future

class CalibrationServiceImpl: CalibrationService {
    var calibrationPersistence: CalibrationPersistence!
    var ruuviTagPersistence: RuuviTagPersistence!
    
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let date = Date()
        let offset = 75.0 - currentValue
        calibrationPersistence.setHumidity(date: date, offset: offset, for: ruuviTag.uuid)
        return ruuviTagPersistence.update(humidityOffset: offset, date: date, of: ruuviTag)
    }
    
    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let date = Date()
        let offset = 100.0 - currentValue
        calibrationPersistence.setHumidity(date: date, offset: offset, for: ruuviTag.uuid)
        return ruuviTagPersistence.update(humidityOffset: offset, date: date, of: ruuviTag)
    }
    
    func cleanHumidityCalibration(for ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        calibrationPersistence.setHumidity(date: nil, offset: 0, for: ruuviTag.uuid)
        return ruuviTagPersistence.clearHumidityCalibration(of: ruuviTag)
    }
    
    func humidityOffset(for uuid: String) -> (Double, Date?) {
        return calibrationPersistence.humidityOffset(for: uuid)
    }
}
