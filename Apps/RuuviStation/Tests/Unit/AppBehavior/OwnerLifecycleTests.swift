import RuuviOntology
import XCTest
@testable import station

@MainActor final class OwnerLifecycleTests: XCTestCase {
    func testRepeatedClaimTapsDoNotSubmitDuplicateOwnershipChanges() async {
        let fixture = OwnerFixture()
        var releases = [CheckedContinuation<Void, Never>]()
        fixture.service.beforeClaim = { await withCheckedContinuation { releases.append($0) } }
        fixture.presenter.viewDidTapOnClaim(mode: .claim)
        await waitForAppState("claim pending") { !releases.isEmpty }
        fixture.presenter.viewDidTapOnClaim(mode: .claim)
        await flushAppBindings()
        XCTAssertEqual(fixture.service.claims.count, 1)
        releases.forEach { $0.resume() }
        await waitForAppState("claim dismissed") { fixture.activity.dismissals.count == releases.count }
        XCTAssertEqual(fixture.router.dismissals, 1)
    }

    func testClosingWhileClaimingReleasesPresenterAndStillFinishesConnectionCleanup() async {
        let fixture = OwnerFixture()
        fixture.measurements.settings.cloudModeEnabled = true
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeClaim = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidTapOnClaim(mode: .claim)
        await waitForAppState("claim pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await waitForAppState("claim indicator dismissed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.connections.changes.first?.0, fixture.measurements.sensor.luid?.value)
        XCTAssertEqual(fixture.connections.changes.first?.1, false)
        XCTAssertEqual(fixture.router.dismissals, 0)
    }

    func testClaimResponseForPreviousSensorDoesNotDismissOrDisconnectTheNewSensor() async {
        let fixture = OwnerFixture()
        fixture.measurements.settings.cloudModeEnabled = true
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeClaim = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidTapOnClaim(mode: .claim)
        await waitForAppState("claim pending") { release != nil }
        var second = fixture.measurements.sensor
        second.macId = "AABBCCDDEEFF".mac
        second.luid = "another-sensor".luid
        fixture.presenter.configure(ruuviTag: second, mode: .claim)
        release?.resume(); release = nil
        await waitForAppState("claim finished") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.connections.changes.first?.0, fixture.measurements.sensor.luid?.value)
        XCTAssertEqual(fixture.router.dismissals, 0)
    }

    func testDelayedOwnerLookupUpdatesTheSensorThatRequestedIt() async {
        let fixture = OwnerFixture()
        var second = fixture.measurements.sensor
        second.macId = "AABBCCDDEEFF".mac
        second.luid = "another-sensor".luid
        fixture.measurements.storage.sensorsOverride = [fixture.measurements.sensor.any, second.any]
        var release: CheckedContinuation<Void, Never>?
        fixture.measurements.storage.beforeReadAll = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.updateOwnerInfo(with: "owner@example.com")
        await waitForAppState("owner lookup pending") { release != nil }
        fixture.presenter.configure(ruuviTag: second, mode: .claim)
        release?.resume(); release = nil
        await waitForAppState("owner saved") { fixture.pool.updatedSensors.count == 1 }
        XCTAssertEqual(fixture.pool.updatedSensors.first?.id, fixture.measurements.sensor.id)
    }
}
