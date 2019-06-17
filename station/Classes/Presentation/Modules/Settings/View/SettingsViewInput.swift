import Foundation

protocol SettingsViewInput: ViewInput {
    var temperatureUnit: TemperatureUnit { get set }
}
