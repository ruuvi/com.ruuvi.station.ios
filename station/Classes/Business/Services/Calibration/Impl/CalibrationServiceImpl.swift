import Foundation
import Future
import RuuviOntology

class CalibrationServiceImpl: CalibrationService {
    var calibrationPersistence: CalibrationPersistence!

    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 75.0 - currentValue
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: luid)
            postHumidityOffsetDidChange(with: luid)
        } else if let macId = ruuviTag.macId {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: macId)
        } else {
            assertionFailure()
        }
    }

    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor) {
        let date = Date()
        let offset = 100.0 - currentValue
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: luid)
            postHumidityOffsetDidChange(with: luid)
        } else if let macId = ruuviTag.macId {
            calibrationPersistence.setHumidity(date: date, offset: offset, for: macId)
        } else {
            assertionFailure()
        }

    }

    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor) {
        if let luid = ruuviTag.luid {
            calibrationPersistence.setHumidity(date: nil, offset: 0, for: luid)
            postHumidityOffsetDidChange(with: luid)
        } else if let macId = ruuviTag.macId {
            calibrationPersistence.setHumidity(date: nil, offset: 0, for: macId)
        } else {
            assertionFailure()
        }

    }

    func humidityOffset(for identifier: Identifier) -> (Double, Date?) {
        return calibrationPersistence.humidityOffset(for: identifier)
    }

    private func postHumidityOffsetDidChange(with identifier: Identifier) {
        let userInfoKey: CalibrationServiceHumidityDidChangeKey
        if identifier is LocalIdentifier {
            userInfoKey = .luid
        } else if identifier is MACIdentifier {
            userInfoKey = .macId
        } else {
            userInfoKey = .luid
            assertionFailure()
        }
        NotificationCenter
            .default
            .post(name: .CalibrationServiceHumidityDidChange,
                  object: nil,
                  userInfo: [userInfoKey: identifier])
    }
}
