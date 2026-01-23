import Foundation
import RuuviOntology

public protocol RuuviServiceAppSettings {
    @discardableResult
    func set(temperatureUnit: TemperatureUnit) async throws -> TemperatureUnit

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(humidityUnit: HumidityUnit) async throws -> HumidityUnit

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(pressureUnit: UnitPressure) async throws -> UnitPressure

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) async throws -> MeasurementAccuracyType

    @discardableResult
    func set(showAllData: Bool) async throws -> Bool

    @discardableResult
    func set(drawDots: Bool) async throws -> Bool

    @discardableResult
    func set(chartDuration: Int) async throws -> Int

    @discardableResult
    func set(showMinMaxAvg: Bool) async throws -> Bool

    @discardableResult
    func set(cloudMode: Bool) async throws -> Bool

    @discardableResult
    func set(dashboard: Bool) async throws -> Bool

    @discardableResult
    func set(dashboardType: DashboardType) async throws -> DashboardType

    @discardableResult
    func set(dashboardTapActionType: DashboardTapActionType) async throws -> DashboardTapActionType

    @discardableResult
    func set(disableEmailAlert: Bool) async throws -> Bool

    @discardableResult
    func set(disablePushAlert: Bool) async throws -> Bool

    @discardableResult
    func set(profileLanguageCode: String) async throws -> String

    @discardableResult
    func set(dashboardSensorOrder: [String]) async throws -> [String]
}
