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
    var reloadWidget: (String) -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
    private var deletionTask: Task<Void, Never>?
    private var marketingTask: Task<Void, Never>?
    private var marketingReadTask: Task<Void, Never>?
    private var logoutTask: Task<Void, Never>?
    private var marketingConsentStatus: RuuviCloudMarketingConsentStatus?
    private var pendingMarketingPreference: Bool?

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

    deinit {
        deletionTask?.cancel()
        marketingTask?.cancel()
        marketingReadTask?.cancel()
        // Confirmed sign-out continues using its captured services after the view closes.
    }

}

// MARK: - MyRuuviAccountViewOutput

extension MyRuuviAccountPresenter: MyRuuviAccountViewOutput {
    func viewDidLoad() {
        syncViewModel()
        refreshMarketingConsent()
    }

    func viewDidTapDeleteButton() {
        guard deletionTask == nil, let email = ruuviUser.email?.lowercased() else { return }
        activityPresenter.show(with: .loading(message: nil))
        deletionTask = Task { @MainActor [weak self, ruuviCloud = ruuviCloud!, activity = activityPresenter!] in
            defer {
                activity.dismiss(immediately: false)
                self?.deletionTask = nil
            }
            do {
                _ = try await ruuviCloud.deleteAccount(email: email)
                guard !Task.isCancelled else { return }
                activity.update(with: .success(message: nil))
                self?.view.viewDidShowAccountDeletionConfirmation()
            } catch {
                guard !Task.isCancelled else { return }
                activity.update(with: .failed(message: nil))
                self?.errorPresenter.present(error: error)
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
        guard marketingTask == nil else { return }
        marketingReadTask?.cancel()
        marketingReadTask = nil
        let previousValue = settings.marketingPreference
        let previousStatus = marketingConsentStatus
        pendingMarketingPreference = isEnabled
        marketingConsentStatus = nil
        syncViewModel()
        activityPresenter.show(with: .loading(message: nil))
        marketingTask = Task {
            @MainActor [weak self, service = ruuviAppSettingsService!, activity = activityPresenter!] in
            var dismissed = false
            defer {
                if !dismissed { activity.dismiss(immediately: false) }
                self?.marketingTask = nil
            }
            do {
                let consent = try await service.set(marketingPreference: isEnabled)
                guard !Task.isCancelled, let self else { return }
                settings.marketingPreference = consent.consent
                marketingConsentStatus = consent.status
                pendingMarketingPreference = nil
                syncViewModel()
                activity.update(with: .success(message: nil))
                if isEnabled, consent.status == .unconfirmed {
                    activity.dismiss(immediately: false)
                    dismissed = true
                    view.viewDidReceiveUnconfirmedMarketingConsent()
                }
            } catch {
                guard !Task.isCancelled, let self else { return }
                settings.marketingPreference = previousValue
                marketingConsentStatus = previousStatus
                pendingMarketingPreference = nil
                syncViewModel()
                activity.update(with: .failed(message: nil))
                errorPresenter.present(error: error)
            }
        }
    }

}

// MARK: - Private

extension MyRuuviAccountPresenter {
    private func refreshMarketingConsent() {
        guard flags.showMarketingPreference, ruuviUser.isAuthorized, marketingTask == nil else { return }
        marketingReadTask?.cancel()
        marketingReadTask = Task { @MainActor [weak self, service = ruuviAppSettingsService!] in
            do {
                let consent = try await service.getMarketingConsent()
                guard !Task.isCancelled, let self else { return }
                settings.marketingPreference = consent.consent
                marketingConsentStatus = consent.status
                syncViewModel()
            } catch {
                // Preserve the last known preference if refreshing the server status fails.
            }
        }
    }

    private func syncViewModel() {
        let viewModel = MyRuuviAccountViewModel()
        if ruuviUser.isAuthorized {
            viewModel.username.value = ruuviUser.email?.lowercased()
        }
        viewModel.showMarketingPreference.value = flags.showMarketingPreference
        viewModel.marketingPreference.value =
            pendingMarketingPreference
            ?? settings.marketingPreference
        viewModel.marketingPreferenceEnabled.value = isMarketingPreferenceEnabled
        viewModel.marketingPreferenceStatusMessage.value = marketingPreferenceStatusMessage
        view.viewModel = viewModel
    }

    private var isMarketingPreferenceEnabled: Bool {
        switch marketingConsentStatus {
        case .subscribed, .unsubscribed, .notFound:
            true
        default:
            false
        }
    }

    private var marketingPreferenceStatusMessage: String? {
        marketingConsentStatus == .unconfirmed
            ? RuuviLocalization.newsletterSubscriptionConfirmation
            : nil
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
            self?.confirmSignOut()
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

    func confirmSignOut() {
        guard logoutTask == nil else { return }
        activityPresenter.show(with: .loading(message: nil))
        let token = pnManager.fcmToken
        logoutTask = Task {
            @MainActor [
                weak self, auth = authService!, notifications = cloudNotificationService!,
                push = pnManager!, settings = settings!, activity = activityPresenter!, reloadWidget
            ] in
            defer {
                activity.dismiss(immediately: false)
                self?.logoutTask = nil
            }
            var push = push
            // Unregister while the account credentials are still available.
            if let token, !token.isEmpty {
                do {
                    let removed = try await notifications.unregister(token: token, tokenId: nil)
                    if removed, push.fcmToken == token {
                        push.fcmToken = nil
                        push.fcmTokenLastRefreshed = nil
                    }
                } catch {
                    // A network failure must not prevent local sign-out.
                }
            }
            do {
                _ = try await auth.logout()
                settings.cloudModeEnabled = false
                activity.update(with: .success(message: nil))
                reloadWidget(AppAssemblyConstants.simpleWidgetKindId)
                reloadWidget(AppAssemblyConstants.multiSensorWidgetKindId)
                self?.router.dismiss()
                self?.syncViewModel()
            } catch {
                activity.update(with: .failed(message: nil))
                self?.errorPresenter.present(error: error)
            }
        }
    }
}
