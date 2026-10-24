@testable import station
import XCTest

final class MarketingConsentPromptHistoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var history: MarketingConsentPromptHistory!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let account = "user@example.com"
    private let day: TimeInterval = 24 * 60 * 60

    override func setUp() {
        super.setUp()
        suiteName = "MarketingConsentPromptHistoryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        history = MarketingConsentPromptHistory(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        history = nil
        defaults = nil
        super.tearDown()
    }

    func testFreshInstallationIsEligibleWithoutAnUpdate() {
        XCTAssertTrue(history.isEligible(account: account, now: now))
    }

    func testCheckingEligibilityDoesNotStartCooldown() {
        XCTAssertTrue(history.isEligible(account: account, now: now))
        history = MarketingConsentPromptHistory(defaults: defaults)
        XCTAssertTrue(history.isEligible(account: account, now: now))
    }

    func testPresentationStartsCooldownAndPersistsAcrossLaunches() {
        history.markPresented(account: account, now: now)
        history = MarketingConsentPromptHistory(defaults: defaults)
        XCTAssertFalse(history.isEligible(account: account, now: now))
        XCTAssertFalse(history.isEligible(account: account, now: now.addingTimeInterval(179 * day)))
    }

    func testExactly180DaysIsStillWithinCooldown() {
        history.markPresented(account: account, now: now)
        XCTAssertFalse(history.isEligible(account: account, now: now.addingTimeInterval(180 * day)))
    }

    func testMoreThan180DaysIsEligibleWithoutAnUpdate() {
        history.markPresented(account: account, now: now)
        XCTAssertTrue(history.isEligible(account: account, now: now.addingTimeInterval(180 * day + 1)))
    }

    func testDefaultIntervalRemains180Days() {
        history.markPresented(account: account, now: now)
        XCTAssertFalse(history.isEligible(account: account, now: now.addingTimeInterval(61)))
    }

    func testShortIntervalStillRequiresMoreThanOneMinute() {
        history.markPresented(account: account, now: now)
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 1, now: now.addingTimeInterval(59)))
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 1, now: now.addingTimeInterval(60)))
        XCTAssertTrue(history.isEligible(account: account, intervalMinutes: 1, now: now.addingTimeInterval(61)))
    }

    func testChangingIntervalDoesNotResetHistory() {
        history.markPresented(account: account, now: now)
        let later = now.addingTimeInterval(61)
        XCTAssertTrue(history.isEligible(account: account, intervalMinutes: 1, now: later))
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 180 * 24 * 60, now: later))
    }

    func testCustomIntervalIsUsedInMinutes() {
        history.markPresented(account: account, now: now)
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 5, now: now.addingTimeInterval(300)))
        XCTAssertTrue(history.isEligible(account: account, intervalMinutes: 5, now: now.addingTimeInterval(301)))
    }

    func testInvalidIntervalsAreClampedToOneMinute() {
        history.markPresented(account: account, now: now)
        for minutes in [0, -1, Int.min] {
            XCTAssertFalse(history.isEligible(
                account: account, intervalMinutes: minutes, now: now.addingTimeInterval(60)
            ))
            XCTAssertTrue(history.isEligible(
                account: account, intervalMinutes: minutes, now: now.addingTimeInterval(61)
            ))
        }
    }

    func testLargeIntervalsDoNotOverflow() {
        history.markPresented(account: account, now: now)
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: Int.max, now: now.addingTimeInterval(day)))
    }

    func testShowingAgainRestartsCooldownFromLatestPresentation() {
        history.markPresented(account: account, now: now)
        let later = now.addingTimeInterval(181 * day)
        history.markPresented(account: account, now: later)
        XCTAssertFalse(history.isEligible(account: account, now: later.addingTimeInterval(day)))
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 1, now: later.addingTimeInterval(60)))
    }

    func testFuturePresentationDateDoesNotBypassEitherCooldown() {
        history.markPresented(account: account, now: now.addingTimeInterval(day))
        XCTAssertFalse(history.isEligible(account: account, now: now))
        XCTAssertFalse(history.isEligible(account: account, intervalMinutes: 1, now: now))
    }

    func testAccountsHaveIndependentCooldownsAndIgnoreCase() {
        history.markPresented(account: account.uppercased(), now: now)
        XCTAssertFalse(history.isEligible(account: account, now: now))
        XCTAssertTrue(history.isEligible(account: "other@example.com", now: now))
    }

    func testMalformedEntryDoesNotResetOtherAccountsCooldowns() {
        defaults.set([account: now, "other@example.com": "invalid"], forKey: "MarketingConsentPrompt.lastShownDates")
        XCTAssertFalse(history.isEligible(account: account, now: now))
        XCTAssertTrue(history.isEligible(account: "other@example.com", now: now))
        history.markPresented(account: "third@example.com", now: now)
        XCTAssertFalse(history.isEligible(account: account, now: now))
    }
}
