import Foundation
import RuuviOntology
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviPresenters
import RuuviUser
import RuuviStorage

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: RuuviLocalSettings!
    var errorPresenter: ErrorPresenter!
    var ruuviReactor: RuuviReactor!
    var alertService: RuuviServiceAlert!
    var realmContext: RealmContext!
    var featureToggleService: FeatureToggleService!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
    var ruuviUser: RuuviUser!
    var ruuviStorage: RuuviStorage!

    private var languageToken: NSObjectProtocol?
    private var ruuviTagsToken: RuuviReactorToken?
    private var sensors: [AnyRuuviTagSensor] = []
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
        ruuviTagsToken = ruuviReactor.observe({ [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let sensors):
                guard let sSelf = self else { return }
                let sensors = sensors.reordered(by: sSelf.settings)
                sSelf.sensors = sensors
                let containsConnectable = sensors.contains(where: { $0.isConnectable == true })
                sSelf.view.isBackgroundVisible = containsConnectable
            case .insert(let sensor):
                sSelf.sensors.append(sensor)
                sSelf.view.isBackgroundVisible = sSelf.view.isBackgroundVisible || sensor.isConnectable
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            default:
                break
            }
        })
        view.experimentalFunctionsEnabled = settings.experimentalFeaturesEnabled
        ruuviStorage.readAll().on(success: { [weak self] tags in
            guard let sSelf = self else { return }
            let cloudTagsCount = tags.filter({ $0.isOwner || $0.isCloud }).count
            let cloudModeVisible = sSelf.ruuviUser.isAuthorized && cloudTagsCount > 0
            sSelf.view.cloudModeVisible = cloudModeVisible
            sSelf.view.cloudModeEnabled = sSelf.settings.cloudModeEnabled
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
                                           description: "Settings.ChooseTemperatureUnit.text".localized(),
                                           selection: settings.temperatureUnit.title)
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
                                           description: "Settings.ChooseHumidityUnit.text".localized(),
                                           selection: settings.humidityUnit.title)
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
                                           description: "Settings.ChoosePressureUnit.text".localized(),
                                           selection: settings.pressureUnit.title)
        router.openSelection(with: viewModel, output: self)
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTapOnLanguage() {
        router.openLanguage()
    }

    func viewDidTapOnDefaults() {
        router.openDefaults()
    }

    func viewDidTapOnHeartbeat() {
        router.openHeartbeat()
    }

    func viewDidTapOnChart() {
        router.openChart()
    }

    func viewDidTapOnExperimental() {
        router.openFeatureToggles()
    }

    func viewDidTriggerShake() {
        guard !settings.experimentalFeaturesEnabled else {
            return
        }
        settings.experimentalFeaturesEnabled = true
        view.experimentalFunctionsEnabled = true
    }

    func viewCloudModeDidChange(isOn: Bool) {
        settings.cloudModeEnabled = isOn
        ruuviAppSettingsService.set(cloudMode: isOn)
    }
}
extension SettingsPresenter: SelectionModuleOutput {
    func selection(module: SelectionModuleInput, didSelectItem item: SelectionItemProtocol) {
        switch item {
        case let temperatureUnit as TemperatureUnit:
            ruuviAppSettingsService.set(temperatureUnit: temperatureUnit)
            view.temperatureUnit = temperatureUnit
        case let humidityUnit as HumidityUnit:
            ruuviAppSettingsService.set(humidityUnit: humidityUnit)
            view.humidityUnit = humidityUnit
        case let pressureUnit as UnitPressure:
            ruuviAppSettingsService.set(pressureUnit: pressureUnit)
            view.pressureUnit = pressureUnit
        default:
            break
        }
        module.dismiss()
    }
}
