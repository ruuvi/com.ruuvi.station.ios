import Foundation

protocol SettingsViewOutput {
    func viewDidLoad()
    func viewDidChange(temperatureUnit: TemperatureUnit)
    func viewDidTriggerClose()
}
