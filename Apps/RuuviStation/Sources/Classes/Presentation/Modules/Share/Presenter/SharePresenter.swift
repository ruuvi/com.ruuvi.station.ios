import Foundation
import Future
import RuuviLocalization
import RuuviOntology
import RuuviPool
import RuuviPresenters
import RuuviReactor
import RuuviService
import UIKit

class SharePresenter {
    weak var view: ShareViewInput!
    var router: ShareRouterInput!

    var activityPresenter: ActivityPresenter!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var ruuviReactor: RuuviReactor!
    var ruuviPool: RuuviPool!

    private var sensor: RuuviTagSensor! {
        didSet {
            fetchShared()
        }
    }

    private var maxShareCount: Int = 10
    private var viewModel: ShareViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }

    private var ruuviTagToken: RuuviReactorToken?

    deinit {
        ruuviTagToken?.invalidate()
    }
}

// MARK: - ShareViewOutput

extension SharePresenter: ShareViewOutput {
    func viewDidLoad() {
        startObservingRuuviTag()
    }

    func viewDidTapSendButton(email: String?) {
        guard let email,
              !email.isEmpty,
              isValidEmail(email)
        else {
            view.showInvalidEmail()
            return
        }

        activityPresenter.show(with: .loading(message: nil))
        ruuviOwnershipService
            .share(macId: sensor.id.mac, with: email.lowercased())
            .on(success: { [weak self] result in
                self?.view.clearInput()
                if let invited = result.invited, invited {
                    self?.view.showSuccessfullyInvited()
                } else {
                    self?.updateShared(email: email.lowercased(), add: true)
                    self?.view.showSuccessfullyShared()
                }

            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.dismiss()
            })
    }

    private func unshareTag(_ email: String) {
        activityPresenter.show(with: .loading(message: nil))
        ruuviOwnershipService
            .unshare(macId: sensor.id.mac, with: email.lowercased())
            .on(success: { [weak self] _ in
                self?.updateShared(email: email.lowercased(), add: false)
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.dismiss()
            })
    }

    func viewDidTapUnshareEmail(_ email: String?) {
        guard let email,
              !email.isEmpty
        else {
            return
        }
        let title: String? = nil
        let message = RuuviLocalization.SharePresenter.UnshareSensor.message(
            email.lowercased()
        )
        let confirmActionTitle = RuuviLocalization.yes
        let cancelActionTitle = RuuviLocalization.no
        let confirmAction = UIAlertAction(
            title: confirmActionTitle,
            style: .default
        ) { [weak self] _ in
            self?.unshareTag(email)
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
}

// MARK: - ShareModuleInput

extension SharePresenter: ShareModuleInput {
    func configure(sensor: RuuviTagSensor) {
        syncMaxShareCount(ruuviTag: sensor)
        viewModel = ShareViewModel(maxCount: maxShareCount)
        self.sensor = sensor
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}

// MARK: - Private

extension SharePresenter {
    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            switch change {
            case let .update(sensor):
                if (sensor.luid?.any != nil &&
                    sensor.luid?.any == self?.sensor.luid?.any)
                    ||
                    (sensor.macId?.any != nil &&
                        sensor.macId?.any == self?.sensor.macId?.any) {
                    self?.sensor = sensor
                }
            default: return
            }
        }
    }

    private func fetchShared() {
        guard !sensor.canShare
        else {
            updateViewModel()
            return
        }

        ruuviOwnershipService
            .loadShared(for: sensor)
            .on(success: { [weak self] shareableSensors in
                guard let sSelf = self else { return }
                if let shareable = shareableSensors
                    .first(where: {
                        $0.id == sSelf.sensor.id
                    }) {
                    guard shareable.canShare
                    else {
                        return
                    }

                    let updated = sSelf.sensor.with(canShare: shareable.canShare)
                    sSelf.ruuviOwnershipService.updateShareable(for: updated)
                    sSelf.sensor = updated
                }
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    private func updateViewModel() {
        viewModel.sharedEmails.value = sensor.sharedTo.map({ $0.lowercased() })
        viewModel.canShare.value = sensor.canShare
        view.reloadTableView()
    }

    private func updateShared(email: String, add: Bool) {
        var sharedTo = sensor.sharedTo
        if add {
            sharedTo.append(email)
        } else {
            if let index = sharedTo.firstIndex(where: { shared in
                shared.lowercased() == email.lowercased()
            }) {
                sharedTo.remove(at: index)
            } else {
                return
            }
        }
        let sensor = sensor.with(sharedTo: sharedTo)
        ruuviOwnershipService.updateShareable(for: sensor)
    }

    private func syncMaxShareCount(ruuviTag: RuuviTagSensor) {
        ruuviPool.readSensorSubscriptionSettings(
            ruuviTag
        ).on(success: { [weak self] subscription in
            if let maxShares = subscription?.maxShares {
                self?.maxShareCount = maxShares
            }
        })
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
