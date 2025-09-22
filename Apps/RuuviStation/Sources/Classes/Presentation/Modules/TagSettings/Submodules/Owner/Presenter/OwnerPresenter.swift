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

    private var ruuviTag: RuuviTagSensor!
    private var ownershipMode: OwnershipMode = .claim {
        didSet {
            view.mode = ownershipMode
        }
    }

    func configure(ruuviTag: RuuviTagSensor, mode: OwnershipMode) {
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
//        Task { [weak self] in
//            guard let self else { return }
//            do {
//                let localSensors = try await ruuviStorage.readAll()
//                if let sensor = localSensors.first(where: { $0.id == ruuviTag.id }) {
//                    // Best-effort update; ignore possible error silently for now
//                    _ = try? await ruuviPool.update(sensor
//                        .with(owner: email.lowercased())
//                        .with(isOwner: false)).asyncValue()
//                }
//            } catch {
//                // Silently ignore; updating owner info is non-critical here
//            }
//        }
    }

    func viewDidTriggerFirmwareUpdateDialog() {
        guard ruuviTag.luid?.value != nil,
              ruuviTag.version < 5,
              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup) else { return }
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
    private func removeConnection() {
        guard settings.cloudModeEnabled
        else {
            return
        }
        if let luid = ruuviTag.luid {
            connectionPersistence.setKeepConnection(false, for: luid)
        }
    }

    private func claimSensor() {
        activityPresenter.show(with: .loading(message: nil))
//        Task { [weak self] in
//            guard let self else { return }
//            defer { activityPresenter.dismiss() }
//            do {
//                // Bridge Future -> async if needed
//                _ = try await ruuviOwnershipService.claim(sensor: ruuviTag).asyncValue()
//                router.dismiss()
//                removeConnection()
//                activityPresenter.show(with: .success(message: nil))
//            } catch {
//                if let ownershipError = error as? RuuviServiceOwnershipError,
//                   case .ruuviCloud(.api(.api(.erSensorAlreadyClaimed))) = ownershipError {
//                    if let luid = ruuviTag.luid {
//                        connectionPersistence.setKeepConnection(false, for: luid)
//                    }
//                    view.showSensorAlreadyClaimedDialog()
//                } else {
//                    activityPresenter.show(with: .failed(message: error.localizedDescription))
//                }
//            }
//        }
    }

    private func unclaimSensor(removeCloudHistory: Bool) {
        activityPresenter.show(with: .loading(message: nil))
//        Task { [weak self] in
//            guard let self else { return }
//            defer { activityPresenter.dismiss() }
//            do {
//                _ = try await ruuviOwnershipService.unclaim(
//                    sensor: ruuviTag,
//                    removeCloudHistory: removeCloudHistory
//                ).asyncValue()
//                router.dismiss()
//                activityPresenter.update(with: .success(message: nil))
//            } catch {
//                activityPresenter.show(with: .failed(message: error.localizedDescription))
//            }
//        }
    }
}
