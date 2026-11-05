import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviPresenters
import RuuviService
import RuuviStorage

enum OwnershipMode {
    case claim
    case unclaim
}

final class OwnerPresenter: OwnerModuleInput {
    weak var view: OwnerViewInput!
    var router: OwnerRouterInput!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var ruuviStorage: RuuviStorage!
    var ruuviPool: RuuviPool!
    var featureToggleService: FeatureToggleService!
    var connectionPersistence: RuuviLocalConnections!
    var settings: RuuviLocalSettings!

    private var ownershipTask: Task<Void, Never>?
    private var context = UUID()
    private var ruuviTag: RuuviTagSensor!
    private var ownershipMode: OwnershipMode = .claim {
        didSet {
            view.mode = ownershipMode
        }
    }

    func configure(ruuviTag: RuuviTagSensor, mode: OwnershipMode) {
        context = UUID()
        self.ruuviTag = ruuviTag
        ownershipMode = mode
    }
}

extension OwnerPresenter: OwnerViewOutput {
    /// This method is responsible for claiming/unclaiming the sensor
    func viewDidTapOnClaim(mode: OwnershipMode) {
        switch mode {
        case .claim:
            claimSensor()
        case .unclaim:
            view.showUnclaimHistoryDataRemovalConfirmationDialog()
        }
    }

    func viewDidConfirmUnclaim(removeCloudHistory: Bool) {
        unclaimSensor(removeCloudHistory: removeCloudHistory)
    }

    /// Update the tag with owner information
    func updateOwnerInfo(with email: String) {
        guard let sensorID = ruuviTag?.id else { return }
        Task { @MainActor [storage = ruuviStorage!, pool = ruuviPool!] in
            do {
                let localSensors = try await storage.readAll()
                guard let sensor = localSensors.first(where: { $0.id == sensorID }) else { return }
                _ = try await pool.update(sensor.with(owner: email.lowercased()).with(isOwner: false))
            } catch {
                // The next sensor sync can refresh owner details if local storage is unavailable.
            }
        }
    }

    func viewDidTriggerFirmwareUpdateDialog() {
        guard ruuviTag.luid?.value != nil,
            ruuviTag.version < 5,
            featureToggleService.isEnabled(.legacyFirmwareUpdatePopup)
        else { return }
        view.showFirmwareUpdateDialog()
    }

    func viewDidConfirmFirmwareUpdate() {
        router.openUpdateFirmware(ruuviTag: ruuviTag)
    }

    func viewDidIgnoreFirmwareUpdateDialog() {
        view.showFirmwareDismissConfirmationUpdateDialog()
    }

    func viewDidDismiss() {
        router.dismiss()
    }
}

extension OwnerPresenter {
    private func claimSensor() { changeOwnership(claiming: true, removeCloudHistory: false) }
    private func unclaimSensor(removeCloudHistory: Bool) {
        changeOwnership(claiming: false, removeCloudHistory: removeCloudHistory)
    }

    private func changeOwnership(claiming: Bool, removeCloudHistory: Bool) {
        guard ownershipTask == nil, let ruuviTag else { return }
        let context = context
        let cloudMode = settings.cloudModeEnabled
        activityPresenter.show(with: .loading(message: nil))
        ownershipTask = Task {
            @MainActor [
                weak self, service = ruuviOwnershipService!, activity = activityPresenter!,
                connections = connectionPersistence!
            ] in
            defer {
                activity.dismiss()
                self?.ownershipTask = nil
            }
            do {
                if claiming {
                    _ = try await service.claim(sensor: ruuviTag)
                    if cloudMode, let luid = ruuviTag.luid { connections.setKeepConnection(false, for: luid) }
                } else {
                    _ = try await service.unclaim(sensor: ruuviTag, removeCloudHistory: removeCloudHistory)
                }
                guard let self, self.context == context else { return }
                router.dismiss()
                if claiming {
                    activity.show(with: .success(message: nil))
                } else {
                    activity.update(with: .success(message: nil))
                }
            } catch {
                let alreadyClaimed: Bool
                if case RuuviServiceError.ruuviCloud(.api(.api(.erSensorAlreadyClaimed))) = error {
                    alreadyClaimed = claiming
                } else {
                    alreadyClaimed = false
                }
                if alreadyClaimed, let luid = ruuviTag.luid { connections.setKeepConnection(false, for: luid) }
                guard let self, self.context == context else { return }
                if alreadyClaimed {
                    view.showSensorAlreadyClaimedDialog()
                } else {
                    activity.show(with: .failed(message: error.localizedDescription))
                }
            }
        }
    }
}
