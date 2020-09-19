import Foundation

protocol SettingsViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var pressureUnit: UnitPressure { get set }
    var language: Language { get set }
    var isBackgroundVisible: Bool { get set }
    var isAdvancedVisible: Bool { get set }
}
