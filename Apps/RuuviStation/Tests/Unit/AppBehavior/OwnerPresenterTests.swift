import RuuviOntology
import XCTest
@testable import station

@MainActor final class OwnerPresenterTests: XCTestCase {
    func testClaimingInCloudModeStopsOnlyTheClaimedSensorsBackgroundConnection() async {
        for cloud in [false, true] {
            let fixture = OwnerFixture()
            fixture.measurements.settings.cloudModeEnabled = cloud
            fixture.presenter.viewDidTapOnClaim(mode: .claim)
            await waitForAppState("claim completed") { fixture.activity.dismissals.count == 1 }
            XCTAssertEqual(fixture.service.claims.map(\.id), [fixture.measurements.sensor.id])
            XCTAssertEqual(fixture.router.dismissals, 1)
            XCTAssertEqual(fixture.activity.shown.count, 2)
            XCTAssertEqual(fixture.connections.changes.count, cloud ? 1 : 0)
            if cloud {
                XCTAssertEqual(fixture.connections.changes.first?.0, fixture.measurements.sensor.luid?.value)
                XCTAssertEqual(fixture.connections.changes.first?.1, false)
            }
        }
    }

    func testAlreadyClaimedSensorShowsItsDialogWhileOtherFailuresKeepTheScreenOpen() async {
        for claimed in [false, true] {
            let fixture = OwnerFixture()
            fixture.service.shareFailure =
                claimed
                ? .ruuviCloud(.api(.api(.erSensorAlreadyClaimed))) : .failedToParseNetworkResponse
            fixture.presenter.viewDidTapOnClaim(mode: .claim)
            await waitForAppState("claim failure") { fixture.activity.dismissals.count == 1 }
            XCTAssertEqual(fixture.view.alreadyClaimed, claimed ? 1 : 0)
            XCTAssertEqual(fixture.connections.changes.count, claimed ? 1 : 0)
            XCTAssertEqual(fixture.router.dismissals, 0)
        }
    }

    func testUnclaimRequiresConfirmationAndPreservesTheCloudHistoryChoice() async {
        for remove in [false, true] {
            let fixture = OwnerFixture()
            fixture.presenter.configure(ruuviTag: fixture.measurements.sensor, mode: .unclaim)
            XCTAssertEqual(fixture.view.mode, .unclaim)
            fixture.presenter.viewDidTapOnClaim(mode: .unclaim)
            XCTAssertEqual(fixture.view.unclaimConfirmation, 1)
            XCTAssertTrue(fixture.service.unclaims.isEmpty)
            fixture.presenter.viewDidConfirmUnclaim(removeCloudHistory: remove)
            await waitForAppState("unclaim completed") { fixture.activity.dismissals.count == 1 }
            XCTAssertEqual(fixture.service.unclaims.first?.0.id, fixture.measurements.sensor.id)
            XCTAssertEqual(fixture.service.unclaims.first?.1, remove)
            XCTAssertEqual(fixture.router.dismissals, 1)
            XCTAssertTrue(fixture.connections.changes.isEmpty)
        }
    }

    func testUnclaimFailureReportsFailureWithoutDismissingTheScreen() async {
        let fixture = OwnerFixture()
        fixture.service.shareFailure = .failedToParseNetworkResponse
        fixture.presenter.viewDidConfirmUnclaim(removeCloudHistory: true)
        await waitForAppState("unclaim failed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.router.dismissals, 0)
        guard case .failed = fixture.activity.shown.last else { return XCTFail("Expected failure status") }
    }

    func testOwnerInfoUpdatesOnlyTheMatchingStoredSensorAndNormalizesTheEmail() async {
        let fixture = OwnerFixture()
        var unrelated = fixture.measurements.sensor
        unrelated.macId = "AABBCCDDEEFF".mac
        unrelated.luid = "unrelated".luid
        fixture.measurements.storage.sensorsOverride = [unrelated.any, fixture.measurements.sensor.any]
        fixture.presenter.updateOwnerInfo(with: "OWNER@example.com")
        await waitForAppState("owner persisted") { fixture.pool.updatedSensors.count == 1 }
        XCTAssertEqual(fixture.pool.updatedSensors.first?.id, fixture.measurements.sensor.id)
        XCTAssertEqual(fixture.pool.updatedSensors.first?.owner, "owner@example.com")
        XCTAssertEqual(fixture.pool.updatedSensors.first?.isOwner, false)
        fixture.measurements.storage.sensorsOverride = [unrelated.any]
        fixture.presenter.updateOwnerInfo(with: "absent@example.com")
        await waitForAppState("missing sensor read") { fixture.measurements.storage.readAllCount == 2 }
        await flushAppBindings()
        XCTAssertEqual(fixture.pool.updatedSensors.count, 1)
        fixture.measurements.storage.failReadAll = true
        fixture.presenter.updateOwnerInfo(with: "unavailable@example.com")
        await waitForAppState("failed read") { fixture.measurements.storage.readAllCount == 3 }
        XCTAssertEqual(fixture.pool.updatedSensors.count, 1)
    }

    func testFirmwareAndDismissActionsRouteToTheConfiguredSensor() {
        let fixture = OwnerFixture()
        fixture.presenter.viewDidTriggerFirmwareUpdateDialog()
        XCTAssertEqual(fixture.view.firmware, 0)
        fixture.presenter.viewDidConfirmFirmwareUpdate()
        fixture.presenter.viewDidIgnoreFirmwareUpdateDialog()
        fixture.presenter.viewDidDismiss()
        XCTAssertEqual(fixture.router.firmware, [fixture.measurements.sensor.id])
        XCTAssertEqual(fixture.view.ignoreFirmware, 1)
        XCTAssertEqual(fixture.router.dismissals, 1)
    }
}
