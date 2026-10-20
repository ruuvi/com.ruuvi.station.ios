@testable import RuuviLocalUserDefaults
import RuuviOntology
import XCTest

final class RuuviLocalSyncStateUserDefaultsTests: XCTestCase {
    private let firstSensor = "AA:BB:CC:DD:EE:01".mac
    private let secondSensor = "AA:BB:CC:DD:EE:02".mac

    func testClearingOneSensorDoesNotSuppressOtherSensors() {
        let state = RuuviLocalSyncStateUserDefaults()

        state.setAutoGattSyncSuppressed(true, for: firstSensor)

        XCTAssertTrue(state.isAutoGattSyncSuppressed(for: firstSensor))
        XCTAssertFalse(state.isAutoGattSyncSuppressed(for: secondSensor))
    }

    func testSuppressionSurvivesSyncTimestampReset() {
        let state = RuuviLocalSyncStateUserDefaults()
        state.setAutoGattSyncSuppressed(true, for: firstSensor)

        state.setGattSyncDate(nil, for: firstSensor)
        state.setAutoGattSyncAttemptDate(nil, for: firstSensor)

        XCTAssertTrue(state.isAutoGattSyncSuppressed(for: firstSensor))
    }

    func testNextForegroundSessionRestoresAutomaticSync() {
        let state = RuuviLocalSyncStateUserDefaults()
        state.setAutoGattSyncSuppressed(true, for: firstSensor)
        state.setAutoGattSyncSuppressed(true, for: secondSensor)

        state.resetAutoGattSyncSuppression()

        XCTAssertFalse(state.isAutoGattSyncSuppressed(for: firstSensor))
        XCTAssertFalse(state.isAutoGattSyncSuppressed(for: secondSensor))
    }

    func testSuppressionIsNotPersistedAcrossAppLaunches() {
        let state = RuuviLocalSyncStateUserDefaults()
        state.setAutoGattSyncSuppressed(true, for: firstSensor)

        let nextLaunchState = RuuviLocalSyncStateUserDefaults()

        XCTAssertFalse(nextLaunchState.isAutoGattSyncSuppressed(for: firstSensor))
    }

    func testFailedClearCanRestoreAutomaticSyncForOnlyThatSensor() {
        let state = RuuviLocalSyncStateUserDefaults()
        state.setAutoGattSyncSuppressed(true, for: firstSensor)
        state.setAutoGattSyncSuppressed(true, for: secondSensor)

        state.setAutoGattSyncSuppressed(false, for: firstSensor)

        XCTAssertFalse(state.isAutoGattSyncSuppressed(for: firstSensor))
        XCTAssertTrue(state.isAutoGattSyncSuppressed(for: secondSensor))
    }
}
