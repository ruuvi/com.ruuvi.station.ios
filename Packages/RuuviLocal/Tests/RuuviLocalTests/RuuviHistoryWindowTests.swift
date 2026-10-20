@testable import RuuviLocal
import XCTest

final class RuuviHistoryWindowTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 10_000_000)

    func testPresentationUsesConfiguredLimit() {
        XCTAssertEqual(start(limit: 240), now.addingTimeInterval(-240 * 3600))
        XCTAssertEqual(start(limit: 720), now.addingTimeInterval(-720 * 3600))
        XCTAssertEqual(start(limit: 24), now.addingTimeInterval(-24 * 3600))
    }

    func testSelectedRangeCannotExposeArchivedHistory() {
        XCTAssertEqual(start(limit: 240, requested: 720), start(limit: 240))
        XCTAssertEqual(start(limit: 240, requested: 6), now.addingTimeInterval(-6 * 3600))
    }

    func testZeroAndInvalidLimitsNeverExposeOlderData() {
        XCTAssertEqual(start(limit: 0), now)
        XCTAssertEqual(start(limit: -24), now)
    }

    private func start(limit: Int, requested: Int? = nil) -> Date {
        RuuviHistoryWindow.start(now: now, limitHours: limit, requestedHours: requested)
    }
}
