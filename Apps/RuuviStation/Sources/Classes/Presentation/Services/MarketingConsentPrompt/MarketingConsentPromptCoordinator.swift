import RuuviCloud
import RuuviLocal
import RuuviLocalization
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit

final class MarketingConsentPromptCoordinator {
    private struct Session: Equatable {
        let account: String
        let apiKey: String
    }

    private let history: MarketingConsentPromptHistory
    private let user: RuuviUser
    private let service: RuuviServiceMarketingConsent
    private let flags: RuuviLocalFlags
    private var activeCheck: (id: UUID, session: Session)?
    private var dialogSession: Session?
    private weak var dialog: RuuviDialogViewController?
    private weak var savingDialog: RuuviDialogViewController?

    init(
        history: MarketingConsentPromptHistory,
        user: RuuviUser,
        service: RuuviServiceMarketingConsent,
        flags: RuuviLocalFlags
    ) {
        self.history = history
        self.user = user
        self.service = service
        self.flags = flags
    }

    func presentIfNeeded(from presenter: UIViewController) {
        let session = currentSession
        if let dialog, dialogSession != session || !flags.showMarketingPreference {
            self.dialog = nil
            dialog.dismiss(animated: true) { [weak self, weak presenter] in
                guard let presenter else { return }
                self?.presentIfNeeded(from: presenter)
            }
            return
        }
        guard flags.showMarketingPreference, let session else {
            activeCheck = nil
            return
        }
        guard dialog == nil, canPresent(from: presenter), isEligible(account: session.account),
              activeCheck?.session != session else { return }

        let requestID = UUID()
        activeCheck = (requestID, session)
        service.getMarketingConsent().observe(on: .main).on(success: { [weak self, weak presenter] consent in
            guard let self, self.activeCheck?.id == requestID else { return }
            self.activeCheck = nil
            guard self.currentSession == session, self.flags.showMarketingPreference else { return }
            // Pending confirmations and blocked addresses cannot opt in again.
            guard !consent.consent, consent.status == .unsubscribed || consent.status == .notFound else { return }
            guard let presenter, self.canPresent(from: presenter),
                  self.isEligible(account: session.account) else { return }
            self.presentDialog(from: presenter, session: session)
        }, failure: { [weak self] _ in
            guard self?.activeCheck?.id == requestID else { return }
            // Failed or stale checks must not start the cooldown or block the next account.
            self?.activeCheck = nil
        })
    }

    private var currentSession: Session? {
        guard user.isAuthorized, let account = user.email, !account.isEmpty,
              let apiKey = user.apiKey, !apiKey.isEmpty else { return nil }
        return Session(account: account.lowercased(), apiKey: apiKey)
    }

    private func isEligible(account: String) -> Bool {
        history.isEligible(account: account, intervalMinutes: flags.marketingConsentPromptIntervalMinutes)
    }

    private func canPresent(from presenter: UIViewController) -> Bool {
        UIApplication.shared.applicationState == .active &&
            presenter.viewIfLoaded?.window != nil &&
            presenter.presentedViewController == nil &&
            presenter.navigationController?.presentedViewController == nil &&
            (presenter.navigationController == nil ||
                presenter.navigationController?.topViewController === presenter) &&
            !presenter.isBeingDismissed && !presenter.isMovingFromParent
    }

    private func presentDialog(from presenter: UIViewController, session: Session) {
        let dialog = RuuviDialogViewController(configuration: RuuviDialogConfiguration(
            title: RuuviLocalization.marketingConsentPromptTitle,
            message: RuuviLocalization.marketingConsentPromptMessage,
            image: RuuviAsset.marketingConsentMail.image,
            primaryActionTitle: RuuviLocalization.ok,
            secondaryActionTitle: RuuviLocalization.marketingConsentPromptDecline
        ))
        self.dialog = dialog
        dialogSession = session
        dialog.onDismiss = { [weak self, weak dialog] in
            guard let self, self.dialog === dialog else { return }
            self.dialog = nil
            self.dialogSession = nil
        }
        dialog.onDidAppear = { [weak self, weak dialog] in
            guard let self else { return }
            guard self.currentSession == session, self.flags.showMarketingPreference else {
                dialog?.dismiss(animated: true)
                return
            }
            self.history.markPresented(account: session.account)
            dialog?.onDidAppear = nil
        }
        dialog.onSecondaryAction = { [weak dialog] in dialog?.dismiss(animated: true) }
        dialog.onPrimaryAction = { [weak self, weak dialog] in
            guard let self, let dialog else { return }
            self.subscribe(session: session, dialog: dialog)
        }
        presenter.present(dialog, animated: true)
    }

    private func subscribe(session: Session, dialog: RuuviDialogViewController) {
        guard self.dialog === dialog, savingDialog !== dialog else { return }
        guard currentSession == session, flags.showMarketingPreference else {
            dialog.dismiss(animated: true)
            return
        }
        dialog.showError(nil)
        savingDialog = dialog
        dialog.setLoading(true)
        service.set(marketingPreference: true).observe(on: .main).on(success: { [weak self, weak dialog] consent in
            self?.completeSave(.success(consent), dialog: dialog, session: session)
        }, failure: { [weak self, weak dialog] error in
            self?.completeSave(.failure(error), dialog: dialog, session: session)
        })
    }

    private func completeSave(
        _ result: Result<RuuviCloudMarketingConsent, RuuviServiceError>,
        dialog: RuuviDialogViewController?,
        session: Session
    ) {
        if savingDialog === dialog { savingDialog = nil }
        guard let dialog, self.dialog === dialog else { return }
        guard currentSession == session, flags.showMarketingPreference else {
            dialog.dismiss(animated: true)
            return
        }
        dialog.setLoading(false)
        switch result {
        case .failure(let error):
            dialog.showError(error.localizedDescription)
        case .success(let consent):
            guard consent.consent || consent.status == .unconfirmed else {
                dialog.showError(RuuviLocalization.activitySavingFail)
                return
            }
            dialog.configure(RuuviDialogConfiguration(
                title: RuuviLocalization.marketingConsentPromptSaved,
                message: consent.status == .unconfirmed ? RuuviLocalization.newsletterSubscriptionConfirmation : nil,
                primaryActionTitle: RuuviLocalization.ok
            ))
            dialog.onPrimaryAction = { [weak dialog] in dialog?.dismiss(animated: true) }
            dialog.onSecondaryAction = nil
        }
    }
}
