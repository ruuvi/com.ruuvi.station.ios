import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceAppSettings {
    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError>

    @discardableResult
    func set(humidityUnit: HumidityUnit) -> Future<HumidityUnit, RuuviServiceError>

    @discardableResult
    func set(pressureUnit: UnitPressure) -> Future<UnitPressure, RuuviServiceError>
}
