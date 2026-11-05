import Foundation
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import RuuviUser
import UIKit

class NotificationsSettingsPresenter: NSObject, NotificationsSettingsModuleInput {
    weak var view: NotificationsSettingsViewInput?
    var router: NotificationsSettingsRouterInput!

    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
    var cloudNotificationService: RuuviServiceCloudNotification!

    private var settingsViewModels: [NotificationsSettingsViewModel] = [] {
        didSet {
            view?.viewModels = settingsViewModels
        }
    }

    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        super.init()
    }

    private var soundSettingsToken: NSObjectProtocol?
    private var emailAlertsSettingsToken: NSObjectProtocol?
    private var pushAlertsSettingsToken: NSObjectProtocol?

    deinit {
        if let token = soundSettingsToken { notificationCenter.removeObserver(token) }
        if let token = emailAlertsSettingsToken { notificationCenter.removeObserver(token) }
        if let token = pushAlertsSettingsToken { notificationCenter.removeObserver(token) }
    }
}

extension NotificationsSettingsPresenter: NotificationsSettingsViewOutput {
    func viewDidLoad() {
        configure()
        startObservingAlertSoundSetting()
        startObservingEmailAlertSetting()
        startObservingPushAlertSetting()
    }

    func viewDidTapSoundSelection() {
        let pushAlertSoundViewModel = PushAlertSoundSelectionViewModel(
            title: RuuviLocalization.settingsAlertSound,
            items: [
                RuuviAlertSound.systemDefault,
                RuuviAlertSound.ruuviSpeak,
            ],
            selection: settings.alertSound
        )
        router.openSelection(with: pushAlertSoundViewModel)
    }
}

extension NotificationsSettingsPresenter {
    private func configure() {
        var viewModels: [NotificationsSettingsViewModel] = []

        viewModels.append(buildLimitAlertNotificationsSettings())

        if ruuviUser.isAuthorized {
            viewModels.append(buildEmailAlertSettings())
            viewModels.append(buildPushSettings())
        }

        viewModels.append(buildSoundSettings())

        settingsViewModels = viewModels
    }

    private func buildEmailAlertSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = RuuviLocalization.settingsEmailAlerts
        viewModel.subtitle = RuuviLocalization.settingsEmailAlertsDescription
        viewModel.boolean.value = !settings.emailAlertDisabled
        viewModel.hideStatusLabel.value = !settings.showSwitchStatusLabel
        viewModel.configType.value = .switcher
        viewModel.settingsType.value = .email

        bind(viewModel.boolean, fire: false) { observer, enabled in
            let alertDisabled = !GlobalHelpers.getBool(from: enabled)
            observer.settings.emailAlertDisabled = alertDisabled
            Task { @MainActor [service = observer.ruuviAppSettingsService!] in
                _ = try? await service.set(disableEmailAlert: alertDisabled)
            }
        }

        return viewModel
    }

    private func buildPushSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = RuuviLocalization.settingsPushAlerts
        viewModel.subtitle = RuuviLocalization.settingsPushAlertsDescription
        viewModel.boolean.value = !settings.pushAlertDisabled
        viewModel.hideStatusLabel.value = !settings.showSwitchStatusLabel
        viewModel.configType.value = .switcher
        viewModel.settingsType.value = .push

        bind(viewModel.boolean, fire: false) { observer, enabled in
            let alertDisabled = !GlobalHelpers.getBool(from: enabled)
            observer.settings.pushAlertDisabled = alertDisabled
            Task { @MainActor [service = observer.ruuviAppSettingsService!] in
                _ = try? await service.set(disablePushAlert: alertDisabled)
            }
        }

        return viewModel
    }

    private func buildLimitAlertNotificationsSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = RuuviLocalization.settingsAlertLimitNotification
        viewModel.subtitle = RuuviLocalization.settingsAlertLimitNotificationDescription
        viewModel.boolean.value = settings.limitAlertNotificationsEnabled
        viewModel.hideStatusLabel.value = !settings.showSwitchStatusLabel
        viewModel.configType.value = .switcher
        viewModel.settingsType.value = .limitAlert

        bind(viewModel.boolean, fire: false) { observer, enabled in
            let isEnabled = GlobalHelpers.getBool(from: enabled)
            observer.settings.limitAlertNotificationsEnabled = isEnabled
        }

        return viewModel
    }

    private func buildSoundSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = RuuviLocalization.settingsAlertSound
        viewModel.subtitle = RuuviLocalization.settingsAlertSoundDescription
        viewModel.value.value = settings.alertSound.title("")
        viewModel.configType.value = .plain
        viewModel.settingsType.value = .alertSound
        return viewModel
    }

    private func startObservingAlertSoundSetting() {
        if let token = soundSettingsToken { notificationCenter.removeObserver(token) }
        soundSettingsToken =
            notificationCenter
            .addObserver(
                forName: .AlertSoundSettingsDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let self else { return }
                    self.configure()
                    let service = self.cloudNotificationService!
                    let sound = self.settings.alertSound
                    let language = self.settings.language
                    let deviceName = UIDevice.modelName
                    Task { @MainActor in
                        _ = try? await service.set(sound: sound, language: language, deviceName: deviceName)
                    }
                }
            )
    }

    private func startObservingEmailAlertSetting() {
        if let token = emailAlertsSettingsToken { notificationCenter.removeObserver(token) }
        emailAlertsSettingsToken =
            notificationCenter
            .addObserver(
                forName: .EmailAlertSettingsDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.updateEmailViewModel()
                }
            )
    }

    private func startObservingPushAlertSetting() {
        if let token = pushAlertsSettingsToken { notificationCenter.removeObserver(token) }
        pushAlertsSettingsToken =
            notificationCenter
            .addObserver(
                forName: .PushAlertSettingsDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.updatePushViewModel()
                }
            )
    }

    private func updateEmailViewModel() {
        if let viewModel = settingsViewModels.first(where: { vm in
            vm.settingsType.value == .email
        }) {
            if viewModel.boolean.value == settings.emailAlertDisabled {
                configure()
            }
        }
    }

    private func updatePushViewModel() {
        if let viewModel = settingsViewModels.first(where: { vm in
            vm.settingsType.value == .push
        }) {
            if viewModel.boolean.value == settings.pushAlertDisabled {
                configure()
            }
        }
    }
}
