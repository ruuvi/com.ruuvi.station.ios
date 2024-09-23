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
        ruuviStorage.readAll().on(success: { [weak self] localSensors in
            guard let sSelf = self else { return }
            if let sensor = localSensors.first(where: { $0.id == sSelf.ruuviTag.id }) {
                sSelf.ruuviPool.update(sensor
                    .with(owner: email.lowercased())
                    .with(isOwner: false))
            }
        })
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
        ruuviOwnershipService
            .claim(sensor: ruuviTag)
            .on(success: { [weak self] _ in
                self?.router.dismiss()
                self?.removeConnection()
                self?.activityPresenter.show(with: .success(message: nil))
            }, failure: { [weak self] error in
                switch error {
                case .ruuviCloud(.api(.api(.erSensorAlreadyClaimed))):
                    if let luid = self?.ruuviTag.luid {
                        self?.connectionPersistence.setKeepConnection(false, for: luid)
                    }
                    self?.view.showSensorAlreadyClaimedDialog()
                default:
                    self?.activityPresenter.show(with: .failed(message: error.localizedDescription))
                }
            }, completion: { [weak self] in
                self?.activityPresenter.dismiss()
            })
    }

    private func unclaimSensor(removeCloudHistory: Bool) {
        activityPresenter.show(with: .loading(message: nil))
        ruuviOwnershipService
            .unclaim(
                sensor: ruuviTag,
                removeCloudHistory: removeCloudHistory
            )
            .on(success: { [weak self] _ in
                self?.router.dismiss()
                self?.activityPresenter.update(with: .success(message: nil))
            }, failure: { [weak self] error in
                self?.activityPresenter.show(with: .failed(message: error.localizedDescription))
            }, completion: { [weak self] in
                self?.activityPresenter.dismiss()
            })
    }
}
