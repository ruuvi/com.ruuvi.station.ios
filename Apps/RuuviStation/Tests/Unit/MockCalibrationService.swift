import Foundation
import Future
@testable import station

class MockCalibrationService: CalibrationService {
    func calibrateHumiditySaltTest(currentValue _: Double, for _: RuuviTagSensor) {}

    func cleanHumidityCalibration(for _: RuuviTagSensor) {}

    func humidityOffset(for _: LocalIdentifier) -> (Double, Date?) {
        (.nan, nil)
    }

    func calibrateHumidityTo100Percent(currentValue _: Double, for _: RuuviTagSensor) {}

    func calibrateHumiditySaltTest(currentValue _: Double, for _: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        .init(value: true)
    }

    func cleanHumidityCalibration(for _: RuuviTagRealmProtocol) -> Future<Bool, RUError> {
        .init(value: true)
    }

    func humidityOffset(for _: String) -> (Double, Date?) {
        (0, Date())
    }

    func calibrateHumidityTo100Percent(currentValue _: Double, for _: RuuviTagSensor) {}
}
