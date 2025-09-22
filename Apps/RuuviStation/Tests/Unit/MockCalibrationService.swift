import Foundation
@testable import station

class MockCalibrationService: CalibrationService {
    // MARK: - Async variants replacing Futures
    func calibrateHumiditySaltTest(currentValue _: Double, for _: RuuviTagSensor) async throws -> Bool { true }
    func cleanHumidityCalibration(for _: RuuviTagSensor) async throws -> Bool { true }
    func humidityOffset(for _: LocalIdentifier) -> (Double, Date?) { (.nan, nil) }
    func calibrateHumidityTo100Percent(currentValue _: Double, for _: RuuviTagSensor) async throws -> Bool { true }

    // Realm-specific overloads
    func calibrateHumiditySaltTest(currentValue _: Double, for _: RuuviTagRealmProtocol) async throws -> Bool { true }
    func cleanHumidityCalibration(for _: RuuviTagRealmProtocol) async throws -> Bool { true }
    func humidityOffset(for _: String) -> (Double, Date?) { (0, Date()) }
    func calibrateHumidityTo100Percent(currentValue _: Double, for _: RuuviTagSensor, realm _: Bool) async throws -> Bool { true }
}
