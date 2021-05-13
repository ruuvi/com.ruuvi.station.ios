import Foundation
import Future

protocol CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor)
    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor)
    func humidityOffset(for luid: LocalIdentifier) -> (Double, Date?)
    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor)
}

extension Notification.Name {
    static let CalibrationServiceHumidityDidChange = Notification.Name("CalibrationServiceDidChange")
    static let OffsetCorrectionDidChange = Notification.Name("OffsetCorrectionDidChange")
}

enum CalibrationServiceHumidityDidChangeKey: String {
    case luid // LocalIdentifier
}

enum OffsetCorrectionDidChangeKey: String {
    case luid // LocalIdentifier
    case ruuviTagId
}
