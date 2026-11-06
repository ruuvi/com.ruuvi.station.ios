import BTKit
import Foundation
import XCTest
@testable import RuuviService
@testable import station

@MainActor final class GATTDownloadOperationTests: XCTestCase {
    func testSuccessfulEmptyHistoryStillCompletesPersistenceAndPublishesItsLifecycle() async throws {
        let fixture = GATTDownloadFixture()
        let notifications = LogNotificationRecorder(uuid: fixture.uuid)
        var progress = 0
        let operation = fixture.operation { _ in progress += 1 }
        operation.start()
        let request = try XCTUnwrap(fixture.radio.requests.first)
        request.progress(.serving)
        request.receive(.success(.points(0)))
        request.receive(.success(.logs([])))
        await waitForAppState("empty history completed") { operation.isFinished }
        await flushAppBindings()
        XCTAssertEqual(progress, 1)
        XCTAssertEqual(fixture.pool.createdBatches.count, 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidStart), 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationProgress), 2)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFinish), 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFail), 0)
        let started = try XCTUnwrap(notifications.notifications.first { $0.name == .RuuviTagReadLogsOperationDidStart })
        XCTAssertEqual(started.userInfo?[RuuviTagReadLogsOperationDidStartKey.fromDate] as? Date, fixture.from)
        XCTAssertNil(operation.error)
    }

    func testBluetoothFailureEndsTheOperationWithoutWritingHistory() async throws {
        let fixture = GATTDownloadFixture()
        let notifications = LogNotificationRecorder(uuid: fixture.uuid)
        let task = fixture.start()
        await waitForAppState("history Bluetooth request") { fixture.radio.requests.count == 1 }
        fixture.radio.requests[0].receive(.failure(.logic(.connectionTimedOut)))
        do { _ = try await task.value; XCTFail("Bluetooth failure succeeded") } catch {
            guard case RuuviServiceError.btkit = error else { return XCTFail("Unexpected \(error)") }
        }
        await flushAppBindings()
        XCTAssertTrue(fixture.pool.createdBatches.isEmpty)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFail), 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFinish), 0)
    }

    func testPersistenceFailureIsReportedAndDoesNotPublishSuccessfulHistory() async throws {
        let fixture = GATTDownloadFixture()
        fixture.pool.recordFailure = .ruuviPersistence(.failedToFindRuuviTag)
        let notifications = LogNotificationRecorder(uuid: fixture.uuid)
        let task = fixture.start()
        await waitForAppState("history before persistence failure") { fixture.radio.requests.count == 1 }
        fixture.radio.requests[0].receive(.success(.logs([])))
        do { _ = try await task.value; XCTFail("Persistence failure succeeded") } catch {
            guard case RuuviServiceError.ruuviPool = error else { return XCTFail("Unexpected \(error)") }
        }
        await flushAppBindings()
        XCTAssertEqual(fixture.pool.createdBatches.count, 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFail), 1)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFinish), 0)
    }

    func testCancelledOperationRejectsLateProgressAndResults() async throws {
        let fixture = GATTDownloadFixture()
        let notifications = LogNotificationRecorder(uuid: fixture.uuid)
        var progress = 0
        let operation = fixture.operation { _ in progress += 1 }
        operation.start()
        let request = try XCTUnwrap(fixture.radio.requests.first)
        operation.cancel()
        operation.stopSync()
        request.progress(.connecting)
        request.receive(.success(.points(4)))
        request.receive(.success(.logs([])))
        request.receive(.failure(.logic(.connectionTimedOut)))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(operation.isFinished)
        XCTAssertTrue(operation.isCancelled)
        XCTAssertEqual(progress, 0)
        XCTAssertNil(operation.currentProgress)
        XCTAssertNil(operation.error)
        XCTAssertEqual(fixture.radio.disconnects, [fixture.uuid])
        XCTAssertTrue(fixture.pool.createdBatches.isEmpty)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFinish), 0)
        XCTAssertEqual(notifications.count(.RuuviTagReadLogsOperationDidFail), 0)
    }

    func testDuplicateTerminalCallbacksCannotPersistTwiceOrReplaceTheCompletedResult() async throws {
        let fixture = GATTDownloadFixture()
        let operation = fixture.operation()
        operation.start()
        let request = try XCTUnwrap(fixture.radio.requests.first)
        request.receive(.success(.logs([])))
        request.receive(.success(.logs([])))
        await waitForAppState("first terminal history result") { operation.isFinished }
        request.receive(.failure(.logic(.connectionTimedOut)))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.pool.createdBatches.count, 1)
        XCTAssertNil(operation.error)
    }

    func testCancelledBeforeStartDoesNotConnectOrPublishAStartNotification() async {
        let fixture = GATTDownloadFixture()
        let notifications = LogNotificationRecorder(uuid: fixture.uuid)
        let operation = fixture.operation()
        operation.cancel(); operation.start()
        await flushAppBindings()
        XCTAssertTrue(fixture.radio.requests.isEmpty)
        XCTAssertTrue(notifications.notifications.isEmpty)
        XCTAssertTrue(operation.isFinished)
    }
}
