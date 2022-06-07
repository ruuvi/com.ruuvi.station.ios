import Foundation
import RuuviOntology

protocol SettingsViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var pressureUnit: UnitPressure { get set }
    var language: Language { get set }
    var isBackgroundVisible: Bool { get set }
    var experimentalFunctionsEnabled: Bool { get set }
    var cloudModeVisible: Bool { get set }
    var cloudModeEnabled: Bool { get set }
    func viewDidShowLanguageChangeDialog()
}
