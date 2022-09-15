import Foundation
import RuuviOntology

protocol SelectionViewInput: ViewInput {
    var viewModel: SelectionViewModel? { get set }
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var pressureUnit: UnitPressure { get set }
}
