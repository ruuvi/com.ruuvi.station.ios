import Foundation
import Future
@testable import station

class MockCalibrationService: CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        return .init(value: true)
    }
    func cleanHumidityCalibration(for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        return .init(value: true)
    }
    func humidityOffset(for uuid: String) -> (Double, Date?) {
        return (0, Date())
    }
    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        return .init(value: false)
    }
}
