import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidChange(temperatureUnit: TemperatureUnit)
    func viewDidChange(humidityUnit: HumidityUnit)
    func viewDidTriggerClose()
    func viewDidTapOnLanguage()
    func viewDidTapOnForeground()
    func viewDidTapOnDefaults()
    func viewDidTapOnHeartbeat()
    func viewDidTapOnAdvanced()
}
