import Foundation
import Future

class CalibrationServiceImpl: CalibrationService {
    var calibrationPersistence: CalibrationPersistence!

    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 75.0 - currentValue
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: luid)
        } else if let macId = ruuviTag.macId {
            // FIXME
//            calibrationPersistence.setHumidity(date: date, offset: offset, for: macId)
        } else {
            assertionFailure()
        }
    }

    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 100.0 - currentValue
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: luid)
        } else if let macId = ruuviTag.macId {
            // FIXME
            // calibrationPersistence.setHumidity(date: date, offset: offset, for: macId)
        } else {
            assertionFailure()
        }

    }

    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor) {
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: nil, offset: 0, for: luid)
        } else if let macId = ruuviTag.macId {
            // FIXME
            // calibrationPersistence.setHumidity(date: nil, offset: 0, for: macId)
        } else {
            assertionFailure()
        }

    }

    func humidityOffset(for luid: LocalIdentifier) -> (Double, Date?) {
        return calibrationPersistence.humidityOffset(for: luid)
    }
}
