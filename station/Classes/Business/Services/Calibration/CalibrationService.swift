import Foundation
import Future

protocol CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
    func cleanHumidityCalibration(for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
    func humidityOffset(for uuid: String) -> (Double, Date?)
    func calibrateHumidityTo100Percent(currentValue: Double,
                                       for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError>
}
