import Foundation

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: Settings!
    
}

extension SettingsPresenter: SettingsViewOutput {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        view.isExperimentalUX = settings.experimentalUX
    }
    
    func viewDidChange(temperatureUnit: TemperatureUnit) {
        settings.temperatureUnit = temperatureUnit
    }
    
    func viewDidChange(experimentalUX: Bool) {
        settings.experimentalUX = experimentalUX
    }
    
    func viewDidTriggerClose() {
        router.dismiss()
    }
}
