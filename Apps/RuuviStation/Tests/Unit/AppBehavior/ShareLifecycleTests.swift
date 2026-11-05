import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class ShareLifecycleTests: XCTestCase {
    func testDuplicateSendTapsDoNotSendOrPersistTheSameInvitationTwice() async {
        let fixture = ShareFixture()
        var releases = [CheckedContinuation<Void, Never>]()
        fixture.service.beforeShare = { await withCheckedContinuation { releases.append($0) } }
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await waitForAppState("share pending") { !releases.isEmpty }
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await flushAppBindings()
        XCTAssertEqual(fixture.service.shares.count, 1)
        let requests = releases.count
        releases.forEach { $0.resume() }
        releases.removeAll()
        await waitForAppState("share requests finished") { fixture.activity.dismissals.count == requests }
        XCTAssertEqual(fixture.service.updates.count, 1)
        XCTAssertEqual(fixture.view.shared, 1)
    }

    func testACompletedShareNeverAddsItsRecipientToADifferentSensor() async {
        let fixture = ShareFixture()
        let original = fixture.sensor
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeShare = { await withCheckedContinuation { release = $0 } }
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await waitForAppState("first sensor sharing") { release != nil }
        var second = fixture.measurements.sensor
        second.macId = "BBAABB112233".mac
        second.luid = "another-sensor".luid
        second.canShare = true
        fixture.presenter.configure(sensor: second)
        release?.resume(); release = nil
        await waitForAppState("original share persisted") { fixture.service.updates.count == 1 }
        XCTAssertEqual(fixture.service.updates.first?.id, original.id)
        XCTAssertEqual(fixture.service.updates.first?.sharedTo, ["friend@example.com"])
        XCTAssertEqual(fixture.view.viewModel.sharedEmails.value, [])
        XCTAssertEqual(fixture.view.shared, 0)
        XCTAssertEqual(fixture.view.cleared, 0)
    }

    func testClosingWhileSharingDoesNotRetainThePresenterOrLeaveTheSpinner() async {
        let fixture = ShareFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.service.beforeShare = { await withCheckedContinuation { release = $0 } }
        fixture.configure()
        fixture.presenter.viewDidLoad()
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await waitForAppState("share waiting") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        XCTAssertTrue(fixture.reactor.sensors.isEmpty)
        release?.resume(); release = nil
        await waitForAppState("share indicator dismissed") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.service.updates.first?.id, fixture.sensor.id)
        XCTAssertEqual(fixture.view.shared, 0)
    }

    func testLateSubscriptionLimitsCannotReplaceThoseOfTheNewSensor() async {
        let fixture = ShareFixture()
        fixture.pool.subscriptions[fixture.sensor.id] = AppSubscription(maxShares: 10, maxSharesPerSensor: 1)
        var release: CheckedContinuation<Void, Never>?
        fixture.pool.beforeSubscription = {
            if fixture.pool.subscriptionReads.count == 1 { await withCheckedContinuation { release = $0 } }
        }
        fixture.configure()
        await waitForAppState("first limits pending") { release != nil }
        var second = fixture.measurements.sensor
        second.macId = "BBAABB112233".mac
        second.luid = "another-sensor".luid
        second.canShare = true
        fixture.pool.subscriptions[second.id] = AppSubscription(maxShares: 50, maxSharesPerSensor: 5)
        fixture.presenter.configure(sensor: second)
        await waitForAppState("second limits") { fixture.view.viewModel.sensorMaxCount == 5 }
        release?.resume(); release = nil
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.view.viewModel.sensorMaxCount, 5)
        XCTAssertEqual(fixture.view.viewModel.planTotalAvailableCount, 50)
    }

    func testSharingAnExistingRecipientDoesNotDuplicateItsAccessEntry() async {
        let fixture = ShareFixture()
        fixture.sensor = fixture.sensor.with(sharedTo: ["FRIEND@example.com"])
        fixture.configure()
        fixture.presenter.viewDidTapSendButton(email: "friend@example.com")
        await waitForAppState("existing share saved") { fixture.service.updates.count == 1 }
        XCTAssertEqual(fixture.service.updates.first?.sharedTo.map { $0.lowercased() }, ["friend@example.com"])
    }

    func testConfirmedUnshareRemovesMatchingAcceptedAndPendingAccessAndReportsFailures() async {
        let fixture = ShareFixture()
        fixture.sensor = fixture.sensor.with(sharedTo: ["FRIEND@example.com", "keep@example.com"])
            .with(sharedToPending: ["Friend@example.com", "pending@example.com"])
        fixture.configure()
        fixture.presenter.confirmUnshare(email: "friend@example.com")
        await waitForAppState("unshare persisted") { fixture.service.updates.count == 1 }
        XCTAssertEqual(fixture.service.unshares.first?.0, fixture.sensor.macId?.value)
        XCTAssertEqual(fixture.service.unshares.first?.1, "friend@example.com")
        XCTAssertEqual(fixture.service.updates.first?.sharedTo, ["keep@example.com"])
        XCTAssertEqual(fixture.service.updates.first?.sharedToPending, ["pending@example.com"])
        fixture.service.shareFailure = .failedToParseNetworkResponse
        fixture.presenter.confirmUnshare(email: "keep@example.com")
        await waitForAppState("unshare failure") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.service.updates.count, 1)
        XCTAssertEqual(fixture.activity.dismissals.count, 2)
    }
}
