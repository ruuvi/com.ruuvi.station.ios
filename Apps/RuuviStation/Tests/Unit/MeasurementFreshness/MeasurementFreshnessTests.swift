@testable import RuuviLocal
@testable import station
import XCTest

final class MeasurementFreshnessTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testDefaultTimeoutMatchesAndroidAndIncludesExactBoundary() {
        XCTAssertEqual(RuuviMeasurementFreshness.defaultTimeoutSeconds, 3600)
        XCTAssertFalse(RuuviMeasurementFreshness.isStale(lastUpdated: now.addingTimeInterval(-3599.9), now: now))
        XCTAssertTrue(RuuviMeasurementFreshness.isStale(lastUpdated: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(RuuviMeasurementFreshness.isStale(lastUpdated: now.addingTimeInterval(-3601), now: now))
    }

    func testNoDataAndFutureTimestampsAreNotOutdatedMeasurements() {
        XCTAssertFalse(RuuviMeasurementFreshness.isStale(lastUpdated: nil, now: now))
        XCTAssertFalse(RuuviMeasurementFreshness.isStale(lastUpdated: now.addingTimeInterval(60), now: now))
    }

    func testDeveloperOverrideAndInvalidPersistedTimeouts() {
        let record = now.addingTimeInterval(-2)
        XCTAssertTrue(RuuviMeasurementFreshness.isStale(lastUpdated: record, timeoutSeconds: 1, now: now))
        XCTAssertFalse(RuuviMeasurementFreshness.isStale(lastUpdated: record, timeoutSeconds: 3, now: now))
        XCTAssertTrue(RuuviMeasurementFreshness.isStale(lastUpdated: record, timeoutSeconds: Int.min, now: now))
        XCTAssertFalse(RuuviMeasurementFreshness.isStale(lastUpdated: record, timeoutSeconds: Int.max, now: now))
    }

    func testTimeoutPersistsAndRemainsSafeForTheDeveloperStepper() {
        let key = "RuuviFeatureFlags.measurementStaleTimeoutSeconds"
        let previous = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(previous, forKey: key) }
        UserDefaults.standard.removeObject(forKey: key)
        let flags = RuuviLocalFlagsUserDefaults()
        XCTAssertEqual(flags.measurementStaleTimeoutSeconds, 3600)
        flags.measurementStaleTimeoutSeconds = 7
        XCTAssertEqual(RuuviLocalFlagsUserDefaults().measurementStaleTimeoutSeconds, 7)
        flags.measurementStaleTimeoutSeconds = 0
        XCTAssertEqual(flags.measurementStaleTimeoutSeconds, 1)
        UserDefaults.standard.set(-2, forKey: key)
        XCTAssertEqual(flags.measurementStaleTimeoutSeconds, 1)
        flags.measurementStaleTimeoutSeconds = Int.max
        XCTAssertEqual(flags.measurementStaleTimeoutSeconds, Int(Int32.max))
        XCTAssertEqual(Int(Double(flags.measurementStaleTimeoutSeconds)), flags.measurementStaleTimeoutSeconds)
    }

    func testTimeoutEditorAcceptsCustomSecondsAndRejectsInvalidInput() {
        let editor = DefaultsIntegerEditorConfiguration(
            range: RuuviMeasurementFreshness.allowedTimeoutSeconds,
            message: "", presets: [], formatValue: String.init
        )
        XCTAssertEqual(editor.validatedValue(from: " 17 "), 17)
        XCTAssertEqual(editor.validatedValue(from: "1"), 1)
        for text in ["", "0", "-1", "1.5", "abc", String(Int.max)] {
            XCTAssertNil(editor.validatedValue(from: text))
        }
    }
}
