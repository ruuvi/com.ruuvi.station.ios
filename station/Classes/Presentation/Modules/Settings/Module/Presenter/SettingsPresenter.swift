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
import UIKit

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
    private var sensors: [AnyRuuviTagSensor] = []
    deinit {
        languageToken?.invalidate()
    }
}

extension SettingsPresenter: SettingsViewOutput {
    func viewDidLoad() {
        view.language = settings.language

        languageToken = NotificationCenter
            .default
            .addObserver(forName: .LanguageDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
            self?.view.language = self?.settings.language ?? .english
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
        let viewModel = UnitSettingsViewModel(title: "TagSettings.OffsetCorrection.Temperature".localized(),
                                              items: selectionItems,
                                              measurementType: .temperature)
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTapHumidityUnit() {
        let selectionItems: [HumidityUnit] = [
            .percent,
            .gm3,
            .dew
        ]
        let viewModel = UnitSettingsViewModel(title: "TagSettings.OffsetCorrection.Humidity".localized(),
                                              items: selectionItems,
                                              measurementType: .humidity)
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTapOnPressure() {
        let selectionItems: [UnitPressure] = [
            .hectopascals,
            .inchesOfMercury,
            .millimetersOfMercury
        ]
        let viewModel = UnitSettingsViewModel(title: "TagSettings.OffsetCorrection.Pressure".localized(),
                                              items: selectionItems,
                                              measurementType: .pressure)
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTapOnLanguage() {
        view.viewDidShowLanguageChangeDialog()
    }

    func viewDidSelectChangeLanguage() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
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
