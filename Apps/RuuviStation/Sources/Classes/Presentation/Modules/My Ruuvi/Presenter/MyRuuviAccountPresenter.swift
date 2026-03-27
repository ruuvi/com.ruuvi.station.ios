import Foundation
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviLocalization
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit

#if canImport(WidgetKit)
    import WidgetKit
#endif

final class MyRuuviAccountPresenter: MyRuuviAccountModuleInput {
    weak var view: MyRuuviAccountViewInput!
    var router: MyRuuviAccountRouterInput!
    var ruuviCloud: RuuviCloud!
    var ruuviUser: RuuviUser!
    var authService: RuuviServiceAuth!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var pnManager: RuuviCorePN!
    var cloudNotificationService: RuuviServiceCloudNotification!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
    var settings: RuuviLocalSettings!
    var flags: RuuviLocalFlags!
    var mailComposerPresenter: MailComposerPresenter!

    private var deleteAccountTask: Task<Void, Never>?
    private var signOutTask: Task<Void, Never>?
    private var marketingPreferenceTask: Task<Void, Never>?

    deinit {
        deleteAccountTask?.cancel()
        signOutTask?.cancel()
        marketingPreferenceTask?.cancel()
    }
}

// MARK: - MyRuuviAccountViewOutput

extension MyRuuviAccountPresenter: MyRuuviAccountViewOutput {
    func viewDidLoad() {
        syncViewModel()
    }

    func viewDidTapDeleteButton() {
        guard let email = ruuviUser.email?.lowercased() else { return }
        activityPresenter.show(with: .loading(message: nil))
        deleteAccountTask?.cancel()
        deleteAccountTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.activityPresenter.dismiss(immediately: false)
            }
            do {
                _ = try await self.ruuviCloud.deleteAccount(email: email)
                self.activityPresenter.update(with: .success(message: nil))
                self.view.viewDidShowAccountDeletionConfirmation()
            } catch let error as RuuviCloudError {
                self.activityPresenter.update(with: .failed(message: nil))
                self.errorPresenter.present(error: error)
            } catch {
                self.activityPresenter.update(with: .failed(message: nil))
                self.errorPresenter.present(error: RuuviCloudError.api(.networking(error)))
            }
        }
    }

    func viewDidTapSignoutButton() {
        createSignOutAlert()
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTriggerSupport(with email: String) {
        mailComposerPresenter.present(email: email.lowercased())
    }

    func viewDidChangeMarketingPreference(isEnabled: Bool) {
        settings.marketingPreference = isEnabled
        marketingPreferenceTask?.cancel()
        marketingPreferenceTask = Task {
            _ = try? await ruuviAppSettingsService.set(marketingPreference: isEnabled)
        }
    }
}

// MARK: - Private

extension MyRuuviAccountPresenter {
    private func syncViewModel() {
        let viewModel = MyRuuviAccountViewModel()
        if ruuviUser.isAuthorized {
            viewModel.username.value = ruuviUser.email?.lowercased()
        }
        viewModel.showMarketingPreference.value = flags.showMarketingPreference
        viewModel.marketingPreference.value = settings.marketingPreference
        view.viewModel = viewModel
    }
}

extension MyRuuviAccountPresenter {
    private func createSignOutAlert() {
        let title = RuuviLocalization.Menu.SignOut.text
        let message = RuuviLocalization.TagsManagerPresenter.SignOutConfirmAlert.message
        let confirmActionTitle = RuuviLocalization.ok
        let cancelActionTitle = RuuviLocalization.cancel
        let confirmAction = UIAlertAction(
            title: confirmActionTitle,
            style: .default
        ) { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.activityPresenter.show(with: .loading(message: nil))
            self?.signOutTask?.cancel()
            self?.signOutTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    self.activityPresenter.dismiss()
                }
                if let token = sSelf.pnManager.fcmToken, !token.isEmpty {
                    _ = try? await sSelf.cloudNotificationService.unregister(
                        token: token,
                        tokenId: nil
                    )
                    sSelf.pnManager.fcmToken = nil
                    sSelf.pnManager.fcmTokenLastRefreshed = nil
                    sSelf.activityPresenter.update(with: .success(message: nil))
                }

                _ = try? await self.authService.logout()
                sSelf.settings.cloudModeEnabled = false
                sSelf.viewDidTriggerClose()
                sSelf.syncViewModel()
                sSelf.reloadWidgets()
            }
        }
        let cancleAction = UIAlertAction(
            title: cancelActionTitle,
            style: .cancel,
            handler: nil
        )
        let actions = [confirmAction, cancleAction]
        let alertViewModel = AlertViewModel(
            title: title,
            message: message,
            style: .alert,
            actions: actions
        )
        alertPresenter.showAlert(alertViewModel)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.multiSensorWidgetKindId
        )
    }
}
