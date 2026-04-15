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

    private var observedSensors: [String: AnyRuuviTagSensor] = [:]
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
                    self?.updatePendingShared(email: email.lowercased(), add: true)
                    self?.view.showSuccessfullyInvited()
                } else {
                    self?.updateAcceptedShared(email: email.lowercased(), add: true)
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
                self?.removeShared(email: email.lowercased())
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
        viewModel = ShareViewModel()
        syncShareLimits(ruuviTag: sensor)
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
            case let .initial(sensors):
                self?.replaceObservedSensors(with: sensors)
                self?.syncPlanShareUsage()
            case let .update(sensor):
                self?.storeObservedSensor(sensor)
                self?.syncPlanShareUsage()
                if (sensor.luid?.any != nil &&
                    sensor.luid?.any == self?.sensor.luid?.any)
                    ||
                    (sensor.macId?.any != nil &&
                        sensor.macId?.any == self?.sensor.macId?.any) {
                    self?.sensor = sensor
                }
            case let .insert(sensor):
                self?.storeObservedSensor(sensor)
                self?.syncPlanShareUsage()
            case let .delete(sensor):
                self?.observedSensors.removeValue(forKey: sensor.id)
                self?.syncPlanShareUsage()
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
                    guard sSelf.sensor.canShare != shareable.canShare
                        || sSelf.sensor.sharedTo != shareable.sharedTo
                        || sSelf.sensor.sharedToPending != shareable.sharedToPending
                    else {
                        sSelf.updateViewModel()
                        return
                    }
                    let updated = sSelf.sensor
                        .with(canShare: shareable.canShare)
                        .with(sharedTo: shareable.sharedTo)
                        .with(sharedToPending: shareable.sharedToPending)
                    sSelf.ruuviOwnershipService.updateShareable(for: updated)
                    sSelf.sensor = updated
                }
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    private func updateViewModel() {
        viewModel.sharedEmails.value = sensor.sharedTo.map({ $0.lowercased() })
        viewModel.pendingSharedEmails.value = sensor.sharedToPending.map({ $0.lowercased() })
        viewModel.canShare.value = sensor.canShare
        view.reloadTableView()
    }

    private func updateAcceptedShared(email: String, add: Bool) {
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

    private func updatePendingShared(email: String, add: Bool) {
        var sharedToPending = sensor.sharedToPending
        if add {
            sharedToPending.append(email)
        } else {
            if let index = sharedToPending.firstIndex(where: { shared in
                shared.lowercased() == email.lowercased()
            }) {
                sharedToPending.remove(at: index)
            } else {
                return
            }
        }
        let sensor = sensor.with(sharedToPending: sharedToPending)
        ruuviOwnershipService.updateShareable(for: sensor)
    }

    private func removeShared(email: String) {
        let sharedTo = sensor.sharedTo.filter { shared in
            shared.lowercased() != email.lowercased()
        }
        let sharedToPending = sensor.sharedToPending.filter { shared in
            shared.lowercased() != email.lowercased()
        }
        let sensor = sensor
            .with(sharedTo: sharedTo)
            .with(sharedToPending: sharedToPending)
        ruuviOwnershipService.updateShareable(for: sensor)
    }

    private func syncShareLimits(ruuviTag: RuuviTagSensor) {
        ruuviPool.readSensorSubscriptionSettings(
            ruuviTag
        ).on(success: { [weak self] subscription in
            self?.viewModel.maxCount.value = subscription?.maxSharesPerSensor ?? 10
            self?.viewModel.totalAvailableCount.value = subscription?.maxShares ?? 0
            self?.view.reloadTableView()
        })
    }

    private func replaceObservedSensors(with sensors: [AnyRuuviTagSensor]) {
        observedSensors = Dictionary(uniqueKeysWithValues: sensors.map { ($0.id, $0) })
    }

    private func storeObservedSensor(_ sensor: AnyRuuviTagSensor) {
        observedSensors[sensor.id] = sensor
    }

    private func syncPlanShareUsage() {
        let totalUsed = observedSensors.values
            .filter { $0.isOwner }
            .reduce(0) { partialResult, sensor in
                partialResult + sensor.sharedTo.count + sensor.sharedToPending.count
            }
        viewModel.totalUsedCount.value = totalUsed
        view.reloadTableView()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}
