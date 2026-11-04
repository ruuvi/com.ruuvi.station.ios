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
        Task { @MainActor [weak self, ruuviStorage = ruuviStorage!] in
            do throws(RuuviStorageError) {
                let value = try await ruuviStorage.readAll()
                ({ [weak self] localSensors in
                    guard let sSelf = self else { return }
                    if let sensor = localSensors.first(where: { $0.id == sSelf.ruuviTag.id }) {
                        Task { @MainActor [self] in
                            _ = try? await sSelf.ruuviPool.update(
                                sensor
                                    .with(owner: email.lowercased())
                                    .with(isOwner: false))
                        }
                    }
                })(value)
            } catch {
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
        Task { @MainActor [weak self, ruuviOwnershipService = ruuviOwnershipService!, ruuviTag = ruuviTag!] in
            defer {
                ({ [weak self] in
                    self?.activityPresenter.dismiss()
                })()
            }
            do throws(RuuviServiceError) {
                let value =
                    try await ruuviOwnershipService
                    .claim(sensor: ruuviTag)
                ({ [weak self] _ in
                    self?.router.dismiss()
                    self?.removeConnection()
                    self?.activityPresenter.show(with: .success(message: nil))
                })(value)
            } catch {
                ({ [weak self] error in
                    switch error {
                    case .ruuviCloud(.api(.api(.erSensorAlreadyClaimed))):
                        if let luid = self?.ruuviTag.luid {
                            self?.connectionPersistence.setKeepConnection(false, for: luid)
                        }
                        self?.view.showSensorAlreadyClaimedDialog()
                    default:
                        self?.activityPresenter.show(with: .failed(message: error.localizedDescription))
                    }
                })(error)
            }
        }
    }

    private func unclaimSensor(removeCloudHistory: Bool) {
        activityPresenter.show(with: .loading(message: nil))
        Task { @MainActor [weak self, ruuviOwnershipService = ruuviOwnershipService!, ruuviTag = ruuviTag!] in
            defer {
                ({ [weak self] in
                    self?.activityPresenter.dismiss()
                })()
            }
            do throws(RuuviServiceError) {
                let value =
                    try await ruuviOwnershipService
                    .unclaim(
                        sensor: ruuviTag,
                        removeCloudHistory: removeCloudHistory
                    )
                ({ [weak self] _ in
                    self?.router.dismiss()
                    self?.activityPresenter.update(with: .success(message: nil))
                })(value)
            } catch {
                ({ [weak self] error in
                    self?.activityPresenter.show(with: .failed(message: error.localizedDescription))
                })(error)
            }
        }
    }
}
