import Foundation

protocol SettingsViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var language: Language { get set }
}
