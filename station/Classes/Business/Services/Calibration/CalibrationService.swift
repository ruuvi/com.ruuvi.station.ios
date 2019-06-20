import Foundation
import Future

protocol CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func cleanHumidityCalibration(for ruuviTag: RuuviTagRealm) -> Future<Bool,RUError>
    func humidityOffset(for uuid: String) -> (Double, Date?)
}
