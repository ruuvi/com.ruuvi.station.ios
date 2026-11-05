import RuuviCloud
import RuuviLocalization
import RuuviOntology
import XCTest
@testable import station

@MainActor final class SharePresenterTests: XCTestCase {
    func testConfigurationShowsNormalizedRecipientsAndSubscriptionLimits() async {
        let fixture = ShareFixture()
        fixture.sensor = fixture.sensor.with(sharedTo: ["FRIEND@example.com"]).with(sharedToPending: [
            "PENDING@example.com"
        ])
        fixture.pool.subscriptions[fixture.sensor.id] = AppSubscription(maxShares: 20, maxSharesPerSensor: 5)
        fixture.configure()
        await waitForAppState("share limits") { fixture.view.viewModel.maxCount.value == 5 }
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["friend@example.com"])
        XCTAssertEqual(fixture.view.viewModel.pendingSharedEmails.value, ["pending@example.com"])
        XCTAssertEqual(fixture.view.viewModel.totalShareCount, 2)
        XCTAssertEqual(fixture.view.viewModel.sensorMaxCount, 5)
        XCTAssertEqual(fixture.view.viewModel.planTotalAvailableCount, 20)
        XCTAssertEqual(fixture.view.viewModel.canShare.value, true)
        XCTAssertTrue(fixture.service.loaded.isEmpty)
    }

    func testInvalidEmailsNeverSendAShareRequestOrShowLoading() async {
        let fixture = ShareFixture()
        fixture.configure()
        for email in [nil, "", "name", "name@", "@example.com", "name@example", " name@example.com"] {
            fixture.presenter.viewDidTapSendButton(email: email)
        }
        await flushAppBindings()
        XCTAssertEqual(fixture.view.invalidEmails, 7)
        XCTAssertTrue(fixture.service.shares.isEmpty)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }

    func testSharingAndInvitingPersistTheCorrectRecipientList() async {
        for invited in [false, true] {
            let fixture = ShareFixture()
            fixture.service.result = ShareSensorResponse(invited: invited)
            fixture.configure()
            fixture.presenter.viewDidTapSendButton(email: "FRIEND@example.com")
            await waitForAppState("share persisted") { fixture.service.updates.count == 1 }
            XCTAssertEqual(fixture.service.shares.first?.0, fixture.sensor.macId?.value)
            XCTAssertEqual(fixture.service.shares.first?.1, "friend@example.com")
            XCTAssertEqual(fixture.service.updates.first?.sharedTo, invited ? [] : ["friend@example.com"])
            XCTAssertEqual(fixture.service.updates.first?.sharedToPending, invited ? ["friend@example.com"] : [])
            XCTAssertEqual(fixture.view.shared, invited ? 0 : 1)
            XCTAssertEqual(fixture.view.invited, invited ? 1 : 0)
            XCTAssertEqual(fixture.view.cleared, 1)
            XCTAssertEqual(fixture.activity.dismissals.count, 1)
        }
    }

    func testShareFailurePreservesTheInputAndExistingRecipients() async {
        let fixture = ShareFixture()
        fixture.sensor = fixture.sensor.with(sharedTo: ["existing@example.com"])
        fixture.service.shareFailure = .failedToParseNetworkResponse
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "new@example.com")
        await waitForAppState("share failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.view.cleared, 0)
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["existing@example.com"])
        XCTAssertTrue(fixture.service.updates.isEmpty)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testUnavailableSharingLoadsAndPersistsUpdatedPermissions() async {
        let fixture = ShareFixture(canShare: false)
        fixture.service.shareable = [
            ShareableSensorStruct(
                id: fixture.sensor.id, canShare: true, sharedTo: ["friend@example.com"],
                sharedToPending: ["pending@example.com"]
            ).any
        ]
        fixture.configure()
        await waitForAppState("sharing permission loaded") { fixture.view.viewModel.canShare.value == true }
        await waitForAppState("shareability persisted") { fixture.service.updates.count == 1 }
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, ["friend@example.com"])
        XCTAssertEqual(fixture.view.viewModel.pendingSharedEmails.value, ["pending@example.com"])
        XCTAssertEqual(fixture.service.loaded, [fixture.sensor.id])
    }

    func testPlanUsageCountsOwnedSensorsAndReplacesInitialSnapshotsWithoutDuplication() {
        let fixture = ShareFixture()
        fixture.configure()
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.reactor.sensors.count, 1)
        let owned = fixture.sensor.with(sharedTo: ["first@example.com"]).with(sharedToPending: ["next@example.com"]).any
        var other = fixture.measurements.sensor
        other.luid = "another-owned-sensor".luid
        other.macId = "AA1122334455".mac
        other.sharedTo = ["other@example.com"]
        other.isOwner = false
        fixture.sendSensors([owned, other.any])
        XCTAssertEqual(fixture.view.viewModel.planTotalUsedCount, 2)
        other.isOwner = true
        Array(fixture.reactor.sensors.values).forEach { $0(.update(other.any)) }
        XCTAssertEqual(fixture.view.viewModel.planTotalUsedCount, 3)
        Array(fixture.reactor.sensors.values).forEach { $0(.insert(other.any)) }
        XCTAssertEqual(fixture.view.viewModel.planTotalUsedCount, 3)
        Array(fixture.reactor.sensors.values).forEach { $0(.delete(other.any)) }
        XCTAssertEqual(fixture.view.viewModel.planTotalUsedCount, 2)
        fixture.sendSensors([])
        XCTAssertEqual(fixture.view.viewModel.planTotalUsedCount, 0)
    }

    func testUnshareRequiresConfirmationAndDismissUsesTheRouter() {
        let fixture = ShareFixture()
        fixture.configure()
        fixture.presenter.viewDidTapUnshareEmail(nil)
        fixture.presenter.viewDidTapUnshareEmail("")
        XCTAssertTrue(fixture.alerts.alerts.isEmpty)
        fixture.presenter.viewDidTapUnshareEmail("FRIEND@example.com")
        XCTAssertEqual(
            fixture.alerts.alerts.first?.message,
            RuuviLocalization.SharePresenter.UnshareSensor.message("friend@example.com"))
        XCTAssertEqual(fixture.alerts.alerts.first?.actions.map(\.style), [.default, .cancel])
        XCTAssertTrue(fixture.service.unshares.isEmpty)
        fixture.presenter.dismiss()
        XCTAssertEqual(fixture.router.dismissals, 1)
    }
}
