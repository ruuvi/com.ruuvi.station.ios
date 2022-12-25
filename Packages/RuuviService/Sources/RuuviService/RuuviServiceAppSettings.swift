import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceAppSettings {
    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError>

    @discardableResult
    func set(temperatureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviServiceError>

    @discardableResult
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviServiceError>

    @discardableResult
    func set(humidityAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviServiceError>

    @discardableResult
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviServiceError>

    @discardableResult
    func set(pressureAccuracy: MeasurementAccuracyType) -> Future<MeasurementAccuracyType, RuuviServiceError>

    @discardableResult
    func set(showAllData: Bool) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func set(drawDots: Bool) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func set(chartDuration: Int) -> Future<Int, RuuviServiceError>

    @discardableResult
    func set(cloudMode: Bool) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func set(dashboard: Bool) -> Future<Bool, RuuviServiceError>

    @discardableResult
    func set(dashboardType: DashboardType) -> Future<DashboardType, RuuviServiceError>
}
