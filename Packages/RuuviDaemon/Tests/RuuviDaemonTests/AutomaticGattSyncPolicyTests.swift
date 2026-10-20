@testable import RuuviDaemonRuuviTag
import XCTest

final class AutomaticGattSyncPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000_000)

    func testFirstObservationIsEligible() {
        XCTAssertTrue(eligible(lastSync: nil, lastAttempt: nil))
    }

    func testRecentAttemptPreventsRetryEvenAfterFailure() {
        XCTAssertFalse(eligible(lastSync: now.addingTimeInterval(-600), lastAttempt: now.addingTimeInterval(-60)))
    }

    func testRecentSuccessfulSyncPreventsRetry() {
        XCTAssertFalse(eligible(lastSync: now.addingTimeInterval(-60), lastAttempt: now.addingTimeInterval(-600)))
    }

    func testCooldownExpiresAtFiveMinutes() {
        XCTAssertFalse(eligible(lastSync: nil, lastAttempt: now.addingTimeInterval(-299)))
        XCTAssertTrue(eligible(lastSync: nil, lastAttempt: now.addingTimeInterval(-300)))
    }

    func testFutureTimestampDoesNotRetryImmediately() {
        XCTAssertFalse(eligible(lastSync: nil, lastAttempt: now.addingTimeInterval(60)))
    }

    func testZeroCooldownAllowsImmediateRetry() {
        XCTAssertTrue(AutomaticGattSyncPolicy.isEligible(
            now: now, lastSync: now, lastAttempt: now, cooldownMinutes: 0
        ))
    }

    func testDisabledCooldownIgnoresFutureTimestamps() {
        let future = now.addingTimeInterval(3600)
        for cooldown in [0, -5] {
            XCTAssertTrue(AutomaticGattSyncPolicy.isEligible(
                now: now, lastSync: future, lastAttempt: nil, cooldownMinutes: cooldown
            ))
            XCTAssertTrue(AutomaticGattSyncPolicy.isEligible(
                now: now, lastSync: nil, lastAttempt: future, cooldownMinutes: cooldown
            ))
        }
    }

    func testHistoryIsClampedToRetentionWindow() {
        let earliest = now.addingTimeInterval(-24 * 60 * 60)
        XCTAssertEqual(AutomaticGattSyncPolicy.syncFrom(now: now, lastSync: nil, historyHours: 24), earliest)
        XCTAssertEqual(AutomaticGattSyncPolicy.syncFrom(
            now: now, lastSync: earliest.addingTimeInterval(-60), historyHours: 24
        ), earliest)
        let recent = now.addingTimeInterval(-600)
        XCTAssertEqual(AutomaticGattSyncPolicy.syncFrom(now: now, lastSync: recent, historyHours: 24), recent)
    }

    private func eligible(lastSync: Date?, lastAttempt: Date?) -> Bool {
        AutomaticGattSyncPolicy.isEligible(now: now, lastSync: lastSync, lastAttempt: lastAttempt, cooldownMinutes: 5)
    }
}
