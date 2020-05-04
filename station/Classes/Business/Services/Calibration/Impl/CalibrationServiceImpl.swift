import Foundation
import Future

class CalibrationServiceImpl: CalibrationService {
    var calibrationPersistence: CalibrationPersistence!

    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 75.0 - currentValue
        calibrationPersistence.setHumidity(date: date, offset: offset, for: ruuviTag.id)
    }

    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 100.0 - currentValue
        calibrationPersistence.setHumidity(date: date, offset: offset, for: ruuviTag.id)
    }

    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor) {
        calibrationPersistence.setHumidity(date: nil, offset: 0, for: ruuviTag.id)
    }

    func humidityOffset(for id: String) -> (Double, Date?) {
        return calibrationPersistence.humidityOffset(for: id)
    }
}
