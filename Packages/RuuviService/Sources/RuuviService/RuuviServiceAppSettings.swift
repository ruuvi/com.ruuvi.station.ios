#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviPool
    import RuuviLocal
    import RuuviRepository
    import RuuviCore
#endif
import Foundation
import RuuviCloud
import RuuviOntology

public protocol RuuviServiceAppSettings: RuuviServiceMarketingConsent {
    @discardableResult
    func set(temperatureUnit: TemperatureUnit) async throws(RuuviServiceError) -> TemperatureUnit

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(humidityUnit: HumidityUnit) async throws(RuuviServiceError) -> HumidityUnit

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(relativeHumidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError)
        -> MeasurementAccuracyType

    @discardableResult
    func set(absoluteHumidityAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError)
        -> MeasurementAccuracyType

    @discardableResult
    func set(dewPointAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(pressureUnit: UnitPressure) async throws(RuuviServiceError) -> UnitPressure

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(pmAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(accelerationAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(voltageAccuracy: MeasurementAccuracyType) async throws(RuuviServiceError) -> MeasurementAccuracyType

    @discardableResult
    func set(showAllData: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(drawDots: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(chartDuration: Int) async throws(RuuviServiceError) -> Int

    @discardableResult
    func set(showMinMaxAvg: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(cloudMode: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(dashboard: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(dashboardType: DashboardType) async throws(RuuviServiceError) -> DashboardType

    @discardableResult
    func set(dashboardTapActionType: DashboardTapActionType) async throws(RuuviServiceError) -> DashboardTapActionType

    @discardableResult
    func set(disableEmailAlert: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(disablePushAlert: Bool) async throws(RuuviServiceError) -> Bool

    @discardableResult
    func set(profileLanguageCode: String) async throws(RuuviServiceError) -> String

    @discardableResult
    func set(dashboardSensorOrder: [String]) async throws(RuuviServiceError) -> [String]
}
