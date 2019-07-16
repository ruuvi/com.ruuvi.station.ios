import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidChange(temperatureUnit: TemperatureUnit)
    func viewDidChange(humidityUnit: HumidityUnit)
    func viewDidChange(experimentalUX: Bool)
    func viewDidTriggerClose()
}
