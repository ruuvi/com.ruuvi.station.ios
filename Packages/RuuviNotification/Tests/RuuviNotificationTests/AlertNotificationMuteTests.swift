#if canImport(RuuviNotificationLocal)
@testable import RuuviNotificationLocal
#else
@testable import RuuviNotification
#endif
import XCTest

final class AlertNotificationMuteTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testActiveMuteSuppressesNotificationsAfterTheRepeatInterval() {
        XCTAssertTrue(RuuviNotificationLocalImpl.isMuted(
            intervalPassed: true,
            mutedTill: now.addingTimeInterval(60),
            now: now
        ))
    }

    func testNotificationsResumeAtMuteExpiryAndAfterward() {
        for expiry in [now, now.addingTimeInterval(-60)] {
            XCTAssertFalse(RuuviNotificationLocalImpl.isMuted(
                intervalPassed: true,
                mutedTill: expiry,
                now: now
            ))
        }
    }

    func testRepeatLimitStillSuppressesNotificationsRegardlessOfMuteExpiry() {
        let expiries: [Date?] = [nil, now, now.addingTimeInterval(-60), now.addingTimeInterval(60)]
        for expiry in expiries {
            XCTAssertTrue(RuuviNotificationLocalImpl.isMuted(
                intervalPassed: false,
                mutedTill: expiry,
                now: now
            ))
        }
    }

    func testUnmutedNotificationsCanBeDeliveredAfterTheRepeatInterval() {
        XCTAssertFalse(RuuviNotificationLocalImpl.isMuted(
            intervalPassed: true,
            mutedTill: nil,
            now: now
        ))
    }
}
