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

    private var latestRecords: [RuuviTagSensorRecord] = []
    private var hasSensors: Bool?
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
        refreshSettingsRows()
    }

    func viewWillAppear() {
        refreshCloudModeVisibility()
    }

    private func refreshSettingsRows() {
        refreshCloudModeVisibility()
    }

    private func refreshCloudModeVisibility() {
        Task { @MainActor [weak self, ruuviStorage = ruuviStorage!] in
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readAll()
                ({ [weak self] tags in
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        let cloudTagsCount = tags.filter { $0.isOwner || $0.isCloud }.count
                        let cloudModeVisible = ruuviUser.isAuthorized && cloudTagsCount > 0
                        view.cloudModeVisible = cloudModeVisible
                    }
                })(value)
            } catch {
            }
        }
    }

    func viewDidTapGlobalUnits() {
        let viewModel = UnitSettingsViewModel(
            title: RuuviLocalization.Settings.Label.globalUnits,
            items: [],
            measurementType: .temperature,
            mode: .globalUnits
        )
        router.openUnitSettings(with: viewModel, output: nil)
    }

    func viewDidTapResolution() {
        loadLatestRecords { [weak self] in
            self?.openResolutionSettings()
        }
    }

    private func loadLatestRecords(completion: @escaping () -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { completion() }
            do {
                let tags = try await ruuviStorage.readAll()
                hasSensors = !tags.isEmpty
                var records = [RuuviTagSensorRecord]()
                for tag in tags {
                    if let record = try await ruuviStorage.readLatest(tag) { records.append(record) }
                }
                latestRecords = records
            } catch { latestRecords = [] }
        }
    }

    private func openResolutionSettings() {
        let viewModel = UnitSettingsViewModel(
            title: RuuviLocalization.Settings.Measurement.Resolution.title,
            items: resolutionTargets(),
            measurementType: .temperature,
            mode: .resolution
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

private extension SettingsPresenter {
    func resolutionTargets() -> [ResolutionSettingsTarget] {
        if hasSensors == false {
            return []
        }

        guard !latestRecords.isEmpty else {
            // Some storage states have sensors before latest records are readable.
            // Without capability metadata here, use the full supported list rather
            // than opening an empty resolution settings screen.
            return ResolutionSettingsTarget.allCases
        }

        var targets = [ResolutionSettingsTarget]()

        if latestRecords.contains(where: { $0.hasMeasurement(for: .temperature) }) {
            targets.append(.temperature)
        }
        if latestRecords.contains(where: { $0.hasMeasurement(for: .humidity) }) {
            targets.append(.relativeHumidity)
        }
        if latestRecords.contains(where: { $0.hasHumidityAndTemperature }) {
            targets.append(.absoluteHumidity)
            targets.append(.dewPoint)
        }
        if latestRecords.contains(where: { $0.hasMeasurement(for: .pressure) }) {
            targets.append(.pressure)
        }
        if latestRecords.contains(where: { $0.hasParticulateMatter }) {
            targets.append(.particulateMatter)
        }
        if latestRecords.contains(where: { $0.hasMeasurement(for: .accelerationX) }) {
            targets.append(.acceleration)
        }
        if latestRecords.contains(where: { $0.hasMeasurement(for: .voltage) }) {
            targets.append(.voltage)
        }

        return targets
    }
}

private extension RuuviTagSensorRecord {
    var hasHumidityAndTemperature: Bool {
        hasMeasurement(for: .humidity) && hasMeasurement(for: .temperature)
    }

    var hasParticulateMatter: Bool {
        hasMeasurement(for: .pm10)
            || hasMeasurement(for: .pm25)
            || hasMeasurement(for: .pm40)
            || hasMeasurement(for: .pm100)
    }
}

extension SettingsPresenter: DefaultsModuleOutput {
    func defaultsModuleDidDismiss(module: DefaultsModuleInput) {
        module.dismiss(completion: { [weak self] in
            self?.router.dismiss()
        })
    }
}
