import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidTapTemperatureUnit()
    func viewDidTapHumidityUnit()
    func viewDidTapOnPressure()
    func viewDidTriggerClose()
    func viewDidTapOnLanguage()
    func viewDidTapOnDefaults()
    func viewDidTapOnHeartbeat()
    func viewDidTapOnAdvanced()
    func viewDidTapOnExperimental()
    func viewDidTriggerShake()
}
