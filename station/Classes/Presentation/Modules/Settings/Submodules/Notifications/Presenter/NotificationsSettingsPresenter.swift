import Foundation
import UIKit
import RuuviOntology
import RuuviLocal
import RuuviService

class NotificationsSettingsPresenter: NSObject, NotificationsSettingsModuleInput {
    weak var view: NotificationsSettingsViewInput?
    var router: NotificationsSettingsRouterInput!

    var settings: RuuviLocalSettings!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
    var cloudNotificationService: RuuviServiceCloudNotification!

    private var settingsViewModels: [NotificationsSettingsViewModel] = [] {
        didSet {
            view?.viewModels = settingsViewModels
        }
    }

    private var soundSettingsToken: NSObjectProtocol?
    private var emailAlertsSettingsToken: NSObjectProtocol?
    private var pushAlertsSettingsToken: NSObjectProtocol?

    deinit {
        soundSettingsToken?.invalidate()
        emailAlertsSettingsToken?.invalidate()
        pushAlertsSettingsToken?.invalidate()
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
            title: "settings_alert_sound".localized(),
            items: [
                RuuviAlertSound.systemDefault,
                RuuviAlertSound.ruuviSpeak
            ],
            selection: settings.alertSound
        )
        router.openSelection(with: pushAlertSoundViewModel)
    }
}

extension NotificationsSettingsPresenter {
    fileprivate func configure() {
        var viewModels: [NotificationsSettingsViewModel] = []

        if settings.showEmailAlertSettings {
            viewModels.append(buildEmailAlertSettings())
        }

        if settings.showPushAlertSettings {
            viewModels.append(buildPushSettings())
        }

        viewModels.append(buildLimitAlertNotificationsSettings())
        viewModels.append(buildSoundSettings())

        settingsViewModels = viewModels
    }

    private func buildEmailAlertSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = "settings_email_alerts".localized()
        viewModel.subtitle = "settings_email_alerts_description".localized()
        viewModel.boolean.value = settings.emailAlertEnabled
        viewModel.configType.value = .switcher
        viewModel.settingsType.value = .email

        bind(viewModel.boolean, fire: false) { observer, enabled in
            let alertEnabled = GlobalHelpers.getBool(from: enabled)
            observer.settings.emailAlertEnabled = alertEnabled
            observer.ruuviAppSettingsService.set(emailAlert: alertEnabled)
        }

        return viewModel
    }

    private func buildPushSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = "settings_push_alerts".localized()
        viewModel.subtitle = "settings_push_alerts_description".localized()
        viewModel.boolean.value = settings.pushAlertEnabled
        viewModel.configType.value = .switcher
        viewModel.settingsType.value = .push

        bind(viewModel.boolean, fire: false) { observer, enabled in
            let alertEnabled = GlobalHelpers.getBool(from: enabled)
            observer.settings.pushAlertEnabled = alertEnabled
            observer.ruuviAppSettingsService.set(pushAlert: alertEnabled)
        }

        return viewModel
    }

    private func buildLimitAlertNotificationsSettings() -> NotificationsSettingsViewModel {
        let viewModel = NotificationsSettingsViewModel()
        viewModel.title = "settings_alert_limit_notification".localized()
        viewModel.subtitle = "settings_alert_limit_notification_description".localized()
        viewModel.boolean.value = settings.limitAlertNotificationsEnabled
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
        viewModel.title = "settings_alert_sound".localized()
        viewModel.subtitle = "settings_alert_sound_description".localized()
        viewModel.value.value = settings.alertSound.title
        viewModel.configType.value = .plain
        viewModel.settingsType.value = .alertSound
        return viewModel
    }

    private func startObservingAlertSoundSetting() {
        soundSettingsToken = NotificationCenter
            .default
            .addObserver(forName: .AlertSoundSettingsDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                self?.configure()
                guard let sSelf = self else { return }
                DispatchQueue.main.async {
                    sSelf.cloudNotificationService.set(
                        sound: sSelf.settings.alertSound,
                        language: sSelf.settings.language,
                        deviceName: UIDevice.modelName
                    )
                }
            })
    }

    private func startObservingEmailAlertSetting() {
        emailAlertsSettingsToken = NotificationCenter
            .default
            .addObserver(forName: .EmailAlertSettingsDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                self?.updateEmailViewModel()
            })
    }

    private func startObservingPushAlertSetting() {
        pushAlertsSettingsToken = NotificationCenter
            .default
            .addObserver(forName: .PushAlertSettingsDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                self?.updatePushViewModel()
            })
    }

    private func updateEmailViewModel() {
        if let viewModel = settingsViewModels.first(where: { vm in
            vm.settingsType.value == .email
        }) {
            if viewModel.boolean.value != settings.emailAlertEnabled {
                configure()
            }
        }
    }

    private func updatePushViewModel() {
        if let viewModel = settingsViewModels.first(where: { vm in
            vm.settingsType.value == .push
        }) {
            if viewModel.boolean.value != settings.pushAlertEnabled {
                configure()
            }
        }
    }
}
