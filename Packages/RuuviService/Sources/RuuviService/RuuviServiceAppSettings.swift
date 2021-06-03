import Foundation
import Future
import RuuviOntology

public protocol RuuviServiceAppSettings {
    @discardableResult
    func set(temperatureUnit: TemperatureUnit) -> Future<TemperatureUnit, RuuviServiceError>
}
