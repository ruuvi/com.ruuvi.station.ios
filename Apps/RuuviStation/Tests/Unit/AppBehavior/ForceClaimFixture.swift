import CoreNFC
import RuuviOntology
import XCTest
@testable import station

@MainActor final class ForceClaimFixture {
    let measurements = MeasurementFixture()
    let service = ShareOwnershipSpy()
    let view = ForceClaimViewSpy()
    let router = ForceClaimRouterSpy()
    let activity = AccountActivitySpy()
    let errors = OffsetErrorSpy()
    var presenter: SensorForceClaimPresenter!
    init() {
        presenter = SensorForceClaimPresenter()
        presenter.view = view
        presenter.router = router
        presenter.ruuviOwnershipService = service
        presenter.activityPresenter = activity
        presenter.settings = measurements.settings
        presenter.errorPresenter = errors
        presenter.configure(ruuviTag: measurements.sensor)
    }
    func message(_ records: [String], prefix: UInt8 = 2) -> NFCNDEFMessage {
        NFCNDEFMessage(
            records: records.map {
                NFCNDEFPayload(
                    format: .nfcWellKnown, type: Data([0x54]), identifier: Data(),
                    payload: Data([prefix]) + Data($0.utf8))
            })
    }
    func scan(secret: String = "test-secret", mac: String? = nil) {
        presenter.viewDidReceiveNFCMessages(messages: [
            message([
                "idID: \(secret)", "adMAC: \(mac ?? measurements.sensor.macId!.value)\0",
            ])
        ])
    }
}

final class ForceClaimViewSpy: SensorForceClaimViewInput {
    var deviceType: RuuviDeviceType = .ruuviTag
    var starts = 0
    var stops = 0
    var hiddenNFC = 0
    var timeouts = 0
    var wrongScans = 0
    func startNFCSession() { starts += 1 }
    func stopNFCSession() { stops += 1 }
    func hideNFCButton() { hiddenNFC += 1 }
    func showGATTConnectionTimeoutDialog() { timeouts += 1 }
    func showWrongTagScanDialog() { wrongScans += 1 }
}
final class ForceClaimRouterSpy: SensorForceClaimRouterInput {
    var dismissals = 0
    func dismiss() { dismissals += 1 }
}
