import Foundation
import RuuviContext
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser
import UIKit

class SettingsPresenter: SettingsModuleInput {
    weak var view: SettingsViewInput!
    var router: SettingsRouterInput!
    var settings: RuuviLocalSettings!
    var errorPresenter: ErrorPresenter!
    var ruuviReactor: RuuviReactor!
    var alertService: RuuviServiceAlert!
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
            .addObserver(
                forName: .LanguageDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.view.language = self?.settings.language ?? .english
                }
            )

        view.experimentalFunctionsEnabled = settings.experimentalFeaturesEnabled
        Task { [weak self] in
            guard let self else { return }
            do {
                let tags = try await ruuviStorage.readAll()
                let cloudTagsCount = tags.filter { $0.isOwner || $0.isCloud }.count
                let cloudModeVisible = ruuviUser.isAuthorized && cloudTagsCount > 0
                await MainActor.run { [weak self] in
                    self?.view.cloudModeVisible = cloudModeVisible
                }
            } catch {
                // Non-critical; ignore or log
            }
        }
    }

    func viewDidTapTemperatureUnit() {
        let selectionItems: [TemperatureUnit] = [
            .celsius,
            .fahrenheit,
            .kelvin,
        ]
        let viewModel = UnitSettingsViewModel(
            title: RuuviLocalization.TagSettings.OffsetCorrection.temperature,
            items: selectionItems,
            measurementType: .temperature
        )
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTapHumidityUnit() {
        let selectionItems: [HumidityUnit] = [
            .percent,
            .gm3,
            .dew,
        ]
        let viewModel = UnitSettingsViewModel(
            title: RuuviLocalization.TagSettings.OffsetCorrection.humidity,
            items: selectionItems,
            measurementType: .humidity(.percent)
        )
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTapOnPressure() {
        let selectionItems: [UnitPressure] = [
            .hectopascals,
            .inchesOfMercury,
            .millimetersOfMercury,
        ]
        let viewModel = UnitSettingsViewModel(
            title: RuuviLocalization.pressure,
            items: selectionItems,
            measurementType: .pressure
        )
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTapOnLanguage() {
        view.viewDidShowLanguageChangeDialog()
    }

    func viewDidSelectChangeLanguage() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString)
        else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }

    func viewDidTapOnDefaults() {
        router.openDefaults(output: self)
    }

    func viewDidTapOnDevices() {
        router.openDevices()
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
        guard !settings.experimentalFeaturesEnabled
        else {
            return
        }
        settings.experimentalFeaturesEnabled = true
        view.experimentalFunctionsEnabled = true
    }

    func viewDidTapRuuviCloud() {
        router.openRuuviCloud()
    }

    func viewDidTapAppearance() {
        router.openAppearance()
    }

    func viewDidTapAlertNotifications() {
        router.openAlertNotificationsSettings()
    }
}

extension SettingsPresenter: DefaultsModuleOutput {
    func defaultsModuleDidDismiss(module: DefaultsModuleInput) {
        module.dismiss(completion: { [weak self] in
            self?.router.dismiss()
        })
    }
}
