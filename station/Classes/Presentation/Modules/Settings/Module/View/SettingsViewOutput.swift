import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidTapTemperatureUnit()
    func viewDidTapHumidityUnit()
    func viewDidTapOnPressure()
    func viewDidTriggerClose()
    func viewDidTapOnLanguage()
    func viewDidTapOnDefaults()
    func viewDidTapOnDevices()
    func viewDidTapOnHeartbeat()
    func viewDidTapOnChart()
    func viewDidTapOnExperimental()
    func viewDidTriggerShake()
    func viewDidTapRuuviCloud()
    func viewDidSelectChangeLanguage()
    func viewDidTapAppearance()
    func viewDidTapAlertNotifications()
}
