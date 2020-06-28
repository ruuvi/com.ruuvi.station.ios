import Foundation
import Future

protocol CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor)
    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor)
    func humidityOffset(for identifier: Identifier) -> (Double, Date?)
    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor)
}

extension Notification.Name {
    static let CalibrationServiceHumidityDidChange = Notification.Name("CalibrationServiceDidChange")
}

enum CalibrationServiceHumidityDidChangeKey: String {
    case luid // LocalIdentifier
    case macId
}
