import Foundation

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: Settings!
    var errorPresenter: ErrorPresenter!
    var ruuviTagReactor: RuuviTagReactor!

    private var languageToken: NSObjectProtocol?
    private var ruuviTagsToken: RUObservationToken?

    deinit {
        ruuviTagsToken?.invalidate()
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

        languageToken = NotificationCenter
            .default
            .addObserver(forName: .LanguageDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
            self?.view.language = self?.settings.language ?? .english
        })

        ruuviTagsToken?.invalidate()
        // TODO: this logic doesn't hide the background if no connectable tags, fix it
        ruuviTagsToken = ruuviTagReactor.observe({ [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let sensors):
                sSelf.view.isBackgroundVisible = sensors.contains(where: { $0.isConnectable == true })
            case .insert(let sensor):
                sSelf.view.isBackgroundVisible = sSelf.view.isBackgroundVisible || sensor.isConnectable
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            default:
                break
            }
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

    func viewDidTapOnForeground() {
        router.openForeground()
    }

    func viewDidTapOnDefaults() {
        router.openDefaults()
    }

    func viewDidTapOnHeartbeat() {
        router.openHeartbeat()
    }
}
