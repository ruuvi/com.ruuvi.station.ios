import Foundation

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: Settings!
}

extension SettingsPresenter: SettingsViewOutput {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        view.humidityUnit = settings.humidityUnit
    }
    
    func viewDidChange(temperatureUnit: TemperatureUnit) {
        settings.temperatureUnit = temperatureUnit
    }
    
    func viewDidChange(humidityUnit: HumidityUnit) {
        settings.humidityUnit = humidityUnit
    }
    
    func viewDidTriggerClose() {
        router.dismiss()
    }
}
