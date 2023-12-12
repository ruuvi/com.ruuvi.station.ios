import Foundation
import RuuviOntology

protocol UnitSettingsViewInput: ViewInput {
    var viewModel: UnitSettingsViewModel? { get set }
    var temperatureUnit: TemperatureUnit { get set }
    var temperatureAccuracy: MeasurementAccuracyType { get set }
    var humidityUnit: HumidityUnit { get set }
    var humidityAccuracy: MeasurementAccuracyType { get set }
    var pressureUnit: UnitPressure { get set }
    var pressureAccuracy: MeasurementAccuracyType { get set }
}
