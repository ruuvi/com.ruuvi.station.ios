import Foundation
import Future
@testable import station

class MockCalibrationService: CalibrationService {
    func calibrateHumiditySaltTest(currentValue: Double, for ruuviTag: RuuviTagSensor) {
    }

    func cleanHumidityCalibration(for ruuviTag: RuuviTagSensor) {
    }

    func humidityOffset(for identifier: Identifier) -> (Double, Date?) {
        return (0, Date())
    }

    func calibrateHumidityTo100Percent(currentValue: Double, for ruuviTag: RuuviTagSensor) {
    }
}
