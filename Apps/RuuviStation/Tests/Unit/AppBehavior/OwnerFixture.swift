import RuuviLocal
import RuuviOntology
import UIKit
@testable import station

@MainActor final class OwnerFixture {
    let measurements = MeasurementFixture()
    let service = ShareOwnershipSpy()
    let pool = AppPoolSpy()
    let connections = AppConnectionsSpy()
    let view = OwnerViewSpy()
    let router = OwnerRouterSpy()
    let errors = OffsetErrorSpy()
    let activity = AccountActivitySpy()
    var presenter: OwnerPresenter!
    init() {
        presenter = OwnerPresenter()
        presenter.view = view
        presenter.router = router
        presenter.errorPresenter = errors
        presenter.activityPresenter = activity
        presenter.ruuviOwnershipService = service
        presenter.ruuviStorage = measurements.storage
        presenter.ruuviPool = pool
        presenter.connectionPersistence = connections
        presenter.settings = measurements.settings
        presenter.featureToggleService = FeatureToggleService()
        pool.allowSensorUpdates = true
        presenter.configure(ruuviTag: measurements.sensor, mode: .claim)
    }
}

final class AppConnectionsSpy: RuuviLocalConnections {
    var changes = [(String, Bool)]()
    var keepConnectionUUIDs: [AnyLocalIdentifier] = []
    func keepConnection(to luid: LocalIdentifier) -> Bool { keepConnectionUUIDs.contains(luid.any) }
    func setKeepConnection(_ value: Bool, for luid: LocalIdentifier) {
        changes.append((luid.value, value))
        keepConnectionUUIDs.removeAll { $0 == luid.any }
        if value { keepConnectionUUIDs.append(luid.any) }
    }
    func unpairAllConnection() { keepConnectionUUIDs.removeAll() }
}

final class OwnerViewSpy: OwnerViewInput {
    var mode: OwnershipMode = .claim
    var alreadyClaimed = 0
    var firmware = 0
    var ignoreFirmware = 0
    var unclaimConfirmation = 0
    func showSensorAlreadyClaimedDialog() { alreadyClaimed += 1 }
    func showFirmwareUpdateDialog() { firmware += 1 }
    func showFirmwareDismissConfirmationUpdateDialog() { ignoreFirmware += 1 }
    func showUnclaimHistoryDataRemovalConfirmationDialog() { unclaimConfirmation += 1 }
}
final class OwnerRouterSpy: OwnerRouterInput {
    var firmware = [String]()
    var dismissals = 0
    func openUpdateFirmware(ruuviTag: RuuviTagSensor) { firmware.append(ruuviTag.id) }
    func dismiss() { dismissals += 1 }
}
