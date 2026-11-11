@testable import RuuviService
import Future
import RuuviLocal
import XCTest

final class CloudMeasurementSyncProgressTests: XCTestCase {
    func testSettingsFailureCannotFinishPendingSensorProgress() {
        let sensor = Promise<Bool, RuuviServiceError>()
        var events: [RuuviCloudSyncEvent] = []
        let measurement = CloudMeasurementSyncProgress.track(publish: { events.append($0) }) { sensor.future }
        let settings = Future<Bool, RuuviServiceError>(error: .failedToParseNetworkResponse)
        XCTAssertNotNil(Future.zip(settings, measurement).error)
        XCTAssertEqual(events.count, 1)
        sensor.succeed(value: true)
        assertCompleted(events)
    }

    func testFailedSensorWorkFinishesItsOwnProgress() {
        let sensor = Promise<Bool, RuuviServiceError>()
        var events: [RuuviCloudSyncEvent] = []
        let measurement = CloudMeasurementSyncProgress.track(publish: { events.append($0) }) { sensor.future }
        sensor.fail(error: .failedToParseNetworkResponse)
        XCTAssertNotNil(measurement.error)
        assertCompleted(events)
    }

    @MainActor
    func testFailedWriteDoesNotFinishUntilSiblingWritesSettle() {
        let failed = Promise<Bool, RuuviServiceError>()
        let pending = Promise<Bool, RuuviServiceError>()
        var events: [RuuviCloudSyncEvent] = []
        let work = CloudMeasurementSyncProgress.track(publish: { events.append($0) }) {
            CloudMeasurementSyncProgress.allSettled([failed.future, pending.future])
        }
        failed.fail(error: .failedToParseNetworkResponse)
        XCTAssertNil(work.error)
        XCTAssertEqual(events.count, 1)
        pending.succeed(value: true)
        XCTAssertNotNil(work.error)
        assertCompleted(events)
    }

    @MainActor
    func testAllSettledPreservesSuccessfulValuesAndHandlesEmptyBatches() {
        let empty: Future<[Bool], RuuviServiceError> = CloudMeasurementSyncProgress.allSettled([])
        XCTAssertEqual(empty.value, [])
        let work = CloudMeasurementSyncProgress.allSettled([
            Future<Bool, RuuviServiceError>(value: true), Future<Bool, RuuviServiceError>(value: false)
        ])
        XCTAssertEqual(work.value, [true, false])
    }

    private func assertCompleted(_ events: [RuuviCloudSyncEvent], file: StaticString = #filePath, line: UInt = #line) {
        guard events.count == 2, case .started(let start) = events[0], case .finished(let finish) = events[1] else {
            return XCTFail("Expected one matched measurement start and finish", file: file, line: line)
        }
        XCTAssertEqual(start, finish, file: file, line: line)
    }
}
