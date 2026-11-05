import Foundation
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

    private var sensor: RuuviTagSensor!
    private var context = UUID()
    private var mutations = Set<String>()
    private var permissionTask: Task<Void, Never>?
    private var limitsTask: Task<Void, Never>?
    private var observedSensors: [String: AnyRuuviTagSensor] = [:]
    private var viewModel: ShareViewModel! {
        didSet { view.viewModel = viewModel }
    }
    private var ruuviTagToken: RuuviReactorToken?

    deinit {
        ruuviTagToken?.invalidate()
        permissionTask?.cancel()
        limitsTask?.cancel()
        // A confirmed share change finishes persisting even after its screen closes.
    }
}

extension SharePresenter: ShareViewOutput {
    func viewDidLoad() {
        startObservingRuuviTag()
    }

    func viewDidTapSendButton(email: String?) {
        guard let email, !email.isEmpty, isValidEmail(email) else {
            view.showInvalidEmail()
            return
        }
        guard sensor.canShare else { return }
        changeSharing(email: email.lowercased(), removing: false)
    }

    func confirmUnshare(email: String) {
        changeSharing(email: email.lowercased(), removing: true)
    }

    func viewDidTapUnshareEmail(_ email: String?) {
        guard let email, !email.isEmpty else { return }
        let confirm = UIAlertAction(title: RuuviLocalization.yes, style: .default) { [weak self] _ in
            self?.confirmUnshare(email: email)
        }
        let cancel = UIAlertAction(title: RuuviLocalization.no, style: .cancel)
        alertPresenter.showAlert(
            AlertViewModel(
                title: nil,
                message: RuuviLocalization.SharePresenter.UnshareSensor.message(email.lowercased()),
                style: .alert,
                actions: [confirm, cancel]
            ))
    }
}

extension SharePresenter: ShareModuleInput {
    func configure(sensor: RuuviTagSensor) {
        context = UUID()
        permissionTask?.cancel()
        limitsTask?.cancel()
        self.sensor = sensor
        viewModel = ShareViewModel()
        updateViewModel()
        syncPlanShareUsage()
        syncShareLimits(ruuviTag: sensor)
        fetchShared()
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}

extension SharePresenter {
    private func changeSharing(email: String, removing: Bool) {
        guard let sensor, mutations.insert(sensor.id).inserted else { return }
        permissionTask?.cancel()
        let context = context
        activityPresenter.show(with: .loading(message: nil))
        Task { @MainActor [weak self, service = ruuviOwnershipService!, activity = activityPresenter!] in
            defer {
                activity.dismiss()
                self?.mutations.remove(sensor.id)
            }
            do {
                let invited: Bool
                if removing {
                    _ = try await service.unshare(macId: sensor.id.mac, with: email)
                    invited = false
                } else {
                    invited = try await service.share(macId: sensor.id.mac, with: email).invited == true
                }
                // Apply the response to its original sensor, preserving newer local metadata.
                let visibleSensor = self?.sensor
                let current: RuuviTagSensor =
                    visibleSensor?.id == sensor.id
                    ? visibleSensor! : self?.observedSensors[sensor.id] ?? sensor.any
                let updated = Self.changingRecipients(of: current, email: email, removing: removing, invited: invited)
                _ = try await service.updateShareable(for: updated)
                guard let self, self.context == context else { return }
                self.sensor = updated
                if observedSensors[updated.id] != nil { observedSensors[updated.id] = updated.any }
                updateViewModel()
                syncPlanShareUsage()
                if !removing {
                    view.clearInput()
                    if invited { view.showSuccessfullyInvited() } else { view.showSuccessfullyShared() }
                }
            } catch {
                guard let self, self.context == context else { return }
                errorPresenter.present(error: error)
            }
        }
    }

    private static func changingRecipients(
        of sensor: RuuviTagSensor, email: String, removing: Bool, invited: Bool
    ) -> RuuviTagSensor {
        var accepted = sensor.sharedTo.filter { $0.lowercased() != email }
        var pending = sensor.sharedToPending.filter { $0.lowercased() != email }
        if !removing {
            if invited { pending.append(email) } else { accepted.append(email) }
        }
        return sensor.with(sharedTo: accepted).with(sharedToPending: pending)
    }

    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let self else { return }
            switch change {
            case let .initial(sensors):
                observedSensors = Dictionary(uniqueKeysWithValues: sensors.map { ($0.id, $0) })
            case let .update(updated):
                observedSensors[updated.id] = updated
                if (updated.luid?.any != nil && updated.luid?.any == sensor.luid?.any)
                    || (updated.macId?.any != nil && updated.macId?.any == sensor.macId?.any)
                {
                    sensor = updated
                    updateViewModel()
                    fetchShared()
                }
            case let .insert(inserted):
                observedSensors[inserted.id] = inserted
            case let .delete(deleted):
                observedSensors.removeValue(forKey: deleted.id)
            default: return
            }
            syncPlanShareUsage()
        }
    }

    private func fetchShared() {
        permissionTask?.cancel()
        guard !sensor.canShare, !mutations.contains(sensor.id) else { return }
        let sensor = sensor!
        let context = context
        permissionTask = Task { @MainActor [weak self, service = ruuviOwnershipService!] in
            do {
                let values = try await service.loadShared(for: sensor)
                guard !Task.isCancelled, self?.context == context,
                    let shareable = values.first(where: { $0.id == sensor.id })
                else { return }
                guard
                    sensor.canShare != shareable.canShare || sensor.sharedTo != shareable.sharedTo
                        || sensor.sharedToPending != shareable.sharedToPending
                else { return }
                let updated = sensor.with(canShare: shareable.canShare).with(sharedTo: shareable.sharedTo)
                    .with(sharedToPending: shareable.sharedToPending)
                _ = try await service.updateShareable(for: updated)
                guard !Task.isCancelled, let self, self.context == context else { return }
                self.sensor = updated
                updateViewModel()
            } catch {
                guard !Task.isCancelled, let self, self.context == context else { return }
                errorPresenter.present(error: error)
            }
        }
    }

    private func updateViewModel() {
        viewModel.sharedEmails.value = sensor.sharedTo.map { $0.lowercased() }
        viewModel.pendingSharedEmails.value = sensor.sharedToPending.map { $0.lowercased() }
        viewModel.canShare.value = sensor.canShare
        view.reloadTableView()
    }

    private func syncShareLimits(ruuviTag: RuuviTagSensor) {
        let context = context
        limitsTask = Task { @MainActor [weak self, pool = ruuviPool!] in
            do {
                let subscription = try await pool.readSensorSubscriptionSettings(ruuviTag)
                guard !Task.isCancelled, let self, self.context == context else { return }
                viewModel.maxCount.value = subscription?.maxSharesPerSensor ?? 10
                viewModel.totalAvailableCount.value = subscription?.maxShares ?? 0
                view.reloadTableView()
            } catch {
                // Keep the default limits if the subscription is unavailable.
            }
        }
    }

    private func syncPlanShareUsage() {
        viewModel.totalUsedCount.value = observedSensors.values.filter { $0.isOwner }.reduce(0) {
            $0 + $1.sharedTo.count + $1.sharedToPending.count
        }
        view.reloadTableView()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
}
