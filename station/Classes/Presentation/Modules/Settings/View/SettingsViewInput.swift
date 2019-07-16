import Foundation

protocol SettingsViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
    var humidityUnit: HumidityUnit { get set }
    var isExperimentalUX: Bool { get set }
}
