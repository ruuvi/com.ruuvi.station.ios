import Foundation
import XCTest
@testable import RuuviLocal

final class WidgetCloudCacheTests: XCTestCase {
    func testFreshnessMarkInvalidationAndInvalidIntervals() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = WidgetCloudCache(userDefaults: defaults)
        XCTAssertFalse(cache.isFresh(intervalMinutes: 60))
        cache.markFresh()
        XCTAssertTrue(cache.isFresh(intervalMinutes: 60))
        XCTAssertTrue(cache.isFresh(intervalMinutes: Int.max), "Converting minutes must not overflow Int")
        XCTAssertFalse(cache.isFresh(intervalMinutes: 0))
        XCTAssertFalse(cache.isFresh(intervalMinutes: -1))
        cache.invalidate()
        XCTAssertFalse(cache.isFresh(intervalMinutes: 60))
        let unavailable = WidgetCloudCache(userDefaults: nil)
        unavailable.markFresh()
        unavailable.invalidate()
        XCTAssertFalse(unavailable.isFresh(intervalMinutes: 60))
    }

    func testExpiredFutureAndMalformedTimestampsRequireRefresh() throws {
        let suite = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cache = WidgetCloudCache(userDefaults: defaults)
        for value: Any in [Date().addingTimeInterval(-7200), Date().addingTimeInterval(3600), "invalid"] {
            defaults.set(value, forKey: "RuuviWidgetCloudFetchTimestamp")
            XCTAssertFalse(cache.isFresh(intervalMinutes: 60))
        }
    }
}
