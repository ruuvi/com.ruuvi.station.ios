import Foundation
import Future

protocol CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor)
    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor)
    func humidityOffset(for id: String) -> (Double, Date?)
    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor)
}
