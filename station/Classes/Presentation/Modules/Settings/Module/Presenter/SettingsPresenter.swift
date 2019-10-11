import Foundation

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: Settings!
    
    private var languageToken: NSObjectProtocol?
    
    deinit {
        if let languageToken = languageToken {
            NotificationCenter.default.removeObserver(languageToken)
        }
    }
}

extension SettingsPresenter: SettingsViewOutput {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        view.humidityUnit = settings.humidityUnit
        view.language = settings.language
        languageToken = NotificationCenter.default.addObserver(forName: .LanguageDidChange, object: nil, queue: .main, using: { [weak self] (notification) in
            self?.view.language = self?.settings.language ?? .english
        })
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
    
    func viewDidTapOnLanguage() {
        router.openLanguage()
    }
    
    func viewDidTapOnDaemons() {
        router.openDaemons()
    }
}
