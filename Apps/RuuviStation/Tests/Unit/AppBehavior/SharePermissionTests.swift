import RuuviOntology
import XCTest
@testable import station

@MainActor final class SharePermissionTests: XCTestCase {
    func testMissingOrUnchangedPermissionResponseKeepsTheCurrentRecipientsAndDoesNotWrite() async {
        for matching in [false, true] {
            let fixture = ShareFixture(canShare: false)
            fixture.sensor = fixture.sensor.with(sharedTo: ["old@example.com"])
            if matching {
                fixture.service.shareable = [
                    ShareableSensorStruct(id: fixture.sensor.id, canShare: false, sharedTo: ["old@example.com"]).any
                ]
            }
            fixture.configure()
            await waitForAppState("permission requested") { fixture.service.loaded.count == 1 }
            await flushAppBindings()
            XCTAssertEqual(fixture.view.viewModel.canShare.value, false)
            XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["old@example.com"])
            XCTAssertTrue(fixture.service.updates.isEmpty)
            fixture.presenter.viewDidTapSendButton(email: "new@example.com")
            await flushAppBindings()
            XCTAssertTrue(fixture.service.shares.isEmpty)
        }
    }

    func testChangedRecipientsWithSharingStillDisabledArePersistedWithoutARefetchLoop() async {
        let fixture = ShareFixture(canShare: false)
        fixture.service.shareable = [
            ShareableSensorStruct(id: fixture.sensor.id, canShare: false, sharedTo: ["old@example.com"]).any
        ]
        fixture.configure()
        await waitForAppState("disabled permission saved") { fixture.service.updates.count == 1 }
        await flushAppBindings()
        XCTAssertEqual(fixture.service.loaded.count, 1)
        XCTAssertEqual(fixture.view.viewModel.canShare.value, false)
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["old@example.com"])
    }

    func testPermissionAndSubscriptionFailuresKeepUsableDefaultState() async {
        let fixture = ShareFixture(canShare: false)
        fixture.service.loadFailure = .failedToParseNetworkResponse
        fixture.pool.subscriptionFailure = .ruuviPersistence(.failedToFindRuuviTag)
        fixture.configure()
        await waitForAppState("permission failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.view.viewModel.canShare.value, false)
        XCTAssertEqual(fixture.view.viewModel.sensorMaxCount, 10)
        XCTAssertEqual(fixture.view.viewModel.planTotalAvailableCount, 0)
        XCTAssertTrue(fixture.service.updates.isEmpty)
    }

    func testLatePermissionResponseCannotChangeOrPersistTheNewSensor() async {
        let fixture = ShareFixture(canShare: false)
        fixture.service.shareable = [
            ShareableSensorStruct(id: fixture.sensor.id, canShare: true, sharedTo: ["old@example.com"]).any
        ]
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeLoad = { await withCheckedContinuation { release = $0 } }
        fixture.configure()
        await waitForAppState("permissions waiting") { release != nil }
        var second = fixture.measurements.sensor
        second.macId = "BBAABB112233".mac
        second.luid = "another-sensor".luid
        second.canShare = true
        second.sharedTo = ["new@example.com"]
        fixture.presenter.configure(sensor: second)
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["new@example.com"])
        XCTAssertEqual(fixture.view.viewModel.canShare.value, true)
        XCTAssertTrue(fixture.service.updates.isEmpty)
    }

    func testConsecutiveSharesPreserveEarlierRecipientsBeforeAReactorUpdate() async {
        let fixture = ShareFixture()
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "first@example.com")
        await waitForAppState("first share") { fixture.activity.dismissals.count == 1 }
        fixture.presenter.viewDidTapSendButton(email: "second@example.com")
        await waitForAppState("second share") { fixture.activity.dismissals.count == 2 }
        XCTAssertEqual(fixture.service.updates.last?.sharedTo, ["first@example.com", "second@example.com"])
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["first@example.com", "second@example.com"])
    }

    func testPersistenceFailureDoesNotReportSuccessOrClearTheDraft() async {
        let fixture = ShareFixture()
        fixture.service.updateFailure = .failedToParseNetworkResponse
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await waitForAppState("share finished") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.errors.errors.count, 1)
        XCTAssertEqual(fixture.view.shared, 0)
        XCTAssertEqual(fixture.view.cleared, 0)
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, [])
    }
}
