import Foundation
import RealmSwift

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: Settings!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!

    private var languageToken: NSObjectProtocol?
    private var connectableRuuviTagsToken: NotificationToken?

    deinit {
        connectableRuuviTagsToken?.invalidate()
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

        connectableRuuviTagsToken?.invalidate()
        connectableRuuviTagsToken = realmContext.main.objects(RuuviTagRealm.self)
            .filter("isConnectable == true").observe({ [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.view.isBackgroundVisible = ruuviTags.count > 0
            case .update(let ruuviTags, _, _, _):
                self?.view.isBackgroundVisible = ruuviTags.count > 0
            case .error(let error):
                self?.errorPresenter.present(error: error)
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

    func viewDidTapOnBackground() {
        router.openBackground()
    }

    func viewDidTapOnDefaults() {
        router.openDefaults()
    }
}
