import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidTapTemperatureUnit()
    func viewDidTapHumidityUnit()
    func viewDidTapOnPressure()
    func viewDidTriggerClose()
    func viewDidTapOnLanguage()
    func viewDidTapOnForeground()
    func viewDidTapOnDefaults()
    func viewDidTapOnHeartbeat()
    func viewDidTapOnAdvanced()
}
