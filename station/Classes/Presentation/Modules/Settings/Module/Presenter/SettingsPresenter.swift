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
        languageToken?.invalidate()
    }
}

extension SettingsPresenter: SettingsViewOutput {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        view.humidityUnit = settings.humidityUnit
        view.language = settings.language
        view.pressureUnit = settings.pressureUnit

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
                let containsConnectable = sensors.contains(where: { $0.isConnectable == true })
                sSelf.view.isBackgroundVisible = containsConnectable
                sSelf.view.isAdvancedVisible = containsConnectable
            case .insert(let sensor):
                sSelf.view.isBackgroundVisible = sSelf.view.isBackgroundVisible || sensor.isConnectable
                sSelf.view.isAdvancedVisible = sSelf.view.isAdvancedVisible || sensor.isConnectable
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            default:
                break
            }
        })
    }

    func viewDidTapTemperatureUnit() {
        let selectionItems: [TemperatureUnit] = [
            .celsius,
            .fahrenheit,
            .kelvin
        ]
        let viewModel = SelectionViewModel(title: "Settings.Label.TemperatureUnit.text".localized(),
                                           items: selectionItems,
                                           description: "Settings.ChooseTemperatureUnit.text".localized())
        router.openSelection(with: viewModel, output: self)
    }

    func viewDidTapHumidityUnit() {
        let selectionItems: [HumidityUnit] = [
            .percent,
            .gm3,
            .dew
        ]
        let viewModel = SelectionViewModel(title: "Settings.Label.HumidityUnit.text".localized(),
                                           items: selectionItems,
                                           description: "Settings.ChooseHumidityUnit.text".localized())
        router.openSelection(with: viewModel, output: self)
    }

    func viewDidTapOnPressure() {
        let selectionItems: [UnitPressure] = [
            .hectopascals,
            .inchesOfMercury,
            .millimetersOfMercury
        ]
        let viewModel = SelectionViewModel(title: "Settings.Label.PressureUnit.text".localized(),
                                           items: selectionItems,
                                           description: "Settings.ChoosePressureUnit.text".localized())
        router.openSelection(with: viewModel, output: self)
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

    func viewDidTapOnAdvanced() {
        router.openAdvanced()
    }
}
extension SettingsPresenter: SelectionModuleOutput {
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol) {
        switch item {
        case let temperatureUnit as TemperatureUnit:
            settings.temperatureUnit = temperatureUnit
            view.temperatureUnit = temperatureUnit
        case let humidityUnit as HumidityUnit:
            settings.humidityUnit = humidityUnit
            view.humidityUnit = humidityUnit
        case let pressureUnit as UnitPressure:
            settings.pressureUnit = pressureUnit
            view.pressureUnit = pressureUnit
        default:
            break
        }
        module.dismiss()
    }
}
