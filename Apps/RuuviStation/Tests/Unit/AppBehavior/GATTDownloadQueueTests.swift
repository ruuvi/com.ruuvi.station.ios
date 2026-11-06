import BTKit
import Foundation
import XCTest
@testable import RuuviService
@testable import station

@MainActor final class GATTDownloadQueueTests: XCTestCase {
    func testDownloadsChooseTheCorrectFirmwareServiceAndForwardDatesTimeoutsAndProgress() async throws {
        for version in [5, 225, 6] {
            let fixture = GATTDownloadFixture()
            let task = fixture.start(firmware: version)
            await waitForAppState("history download started") { fixture.radio.requests.count == 1 }
            let request = try XCTUnwrap(fixture.radio.requests.first)
            XCTAssertEqual(request.uuid, fixture.uuid)
            XCTAssertEqual(request.from, fixture.from)
            XCTAssertEqual(request.connectionTimeout, 12)
            XCTAssertEqual(request.serviceTimeout, 34)
            if version == 5 { XCTAssertEqual(request.service, .all) } else { XCTAssertEqual(request.service, .e1) }
            XCTAssertTrue(fixture.service.isSyncingLogs())
            XCTAssertFalse(fixture.service.isSyncingLogsQueued(with: fixture.uuid))
            request.progress(.connecting)
            request.receive(.success(.points(42)))
            if case .reading(let count) = fixture.service.syncProgress(with: fixture.uuid) {
                XCTAssertEqual(count, 42)
            } else {
                XCTFail("History progress missing")
            }
            request.receive(.success(.logs([])))
            let saved = try await task.value
            XCTAssertTrue(saved)
            XCTAssertEqual(fixture.pool.createdBatches.count, 1)
            XCTAssertFalse(fixture.service.isSyncingLogs())
            XCTAssertFalse(fixture.service.isSyncingLogs(with: fixture.uuid))
            XCTAssertFalse(fixture.service.isSyncingLogsQueued(with: fixture.uuid))
            XCTAssertNil(fixture.service.syncProgress(with: fixture.uuid))
        }
    }

    func testSameSensorCannotDownloadTwiceAndQueuedSensorsStartOnlyWhenASlotIsAvailable() async throws {
        let fixture = GATTDownloadFixture(concurrent: 1)
        let first = fixture.start()
        await waitForAppState("first history request") { fixture.radio.requests.count == 1 }
        let duplicate = fixture.start()
        do { _ = try await duplicate.value; XCTFail("Duplicate download accepted") } catch {
            guard case RuuviServiceError.isAlreadySyncingLogsWithThisTag = error else {
                return XCTFail("Unexpected \(error)")
            }
        }
        let secondID = UUID().uuidString
        let second = fixture.start(uuid: secondID)
        await waitForAppState("second download queued") { fixture.service.isSyncingLogsQueued(with: secondID) }
        XCTAssertEqual(fixture.radio.requests.count, 1)
        fixture.radio.requests[0].receive(.success(.logs([])))
        let firstSaved = try await first.value
        XCTAssertTrue(firstSaved)
        await waitForAppState("queued download started") { fixture.radio.requests.count == 2 }
        XCTAssertEqual(fixture.radio.requests[1].uuid, secondID)
        fixture.radio.requests[1].receive(.success(.logs([])))
        let secondSaved = try await second.value
        XCTAssertTrue(secondSaved)
        XCTAssertFalse(fixture.service.isSyncingLogs())
    }

    func testStoppingQueuedDownloadsPreventsBluetoothWorkAndUnknownSensorsReturnFalse() async throws {
        let fixture = GATTDownloadFixture(concurrent: 1)
        let first = fixture.start()
        await waitForAppState("first history request") { fixture.radio.requests.count == 1 }
        let secondID = UUID().uuidString
        let second = fixture.start(uuid: secondID)
        await waitForAppState("queued history request") { fixture.service.isSyncingLogsQueued(with: secondID) }
        let stopped = try await fixture.service.stopGattSync(for: secondID)
        XCTAssertTrue(stopped)
        fixture.radio.requests[0].receive(.success(.logs([])))
        _ = try await first.value
        let saved = try await second.value
        XCTAssertFalse(saved)
        XCTAssertEqual(fixture.radio.requests.count, 1)
        let missing = try await fixture.service.stopGattSync(for: "unknown")
        XCTAssertFalse(missing)
    }

    func testCancellationWaitsForAlreadyStartedPersistenceBeforeReturning() async throws {
        let fixture = GATTDownloadFixture()
        var resumeWrite: CheckedContinuation<Void, Never>?
        defer { resumeWrite?.resume() }
        fixture.pool.beforeCreateBatch = { await withCheckedContinuation { resumeWrite = $0 } }
        var returned = false
        let task = Task { @MainActor in
            let result = try await fixture.service.syncLogs(
                uuid: fixture.uuid, mac: nil, firmware: 5, from: fixture.from, settings: nil)
            returned = true
            return result
        }
        await waitForAppState("history request started") { fixture.radio.requests.count == 1 }
        fixture.radio.requests[0].receive(.success(.logs([])))
        await waitForAppState("history persistence started") { fixture.pool.createdBatches.count == 1 }
        task.cancel()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertFalse(returned)
        XCTAssertTrue(fixture.service.isSyncingLogs(with: fixture.uuid))
        XCTAssertEqual(fixture.radio.disconnects, [fixture.uuid])
        resumeWrite?.resume(); resumeWrite = nil
        let saved = try await task.value
        XCTAssertFalse(saved)
        XCTAssertTrue(returned)
        XCTAssertFalse(fixture.service.isSyncingLogs())
    }
}
