import Foundation
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
import XCTest
#if SWIFT_PACKAGE
    import RuuviDaemon
    @testable import RuuviDaemonRuuviTag
#else
    @testable import RuuviDaemon
#endif

@MainActor final class SensorPropertiesLifecycleTests: XCTestCase {
    func testStartStopAreIdempotentAndIgnoreCallbacksFromAPreviousSession() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        worker.stop()
        worker.start()
        worker.start()
        XCTAssertEqual(fixture.observations.count, 1)
        fixture.observations[0](.initial([]))
        XCTAssertTrue(fixture.scans.isEmpty)
        fixture.observations[0](.insert(fixture.stored.any))
        XCTAssertEqual(fixture.scans.count, 1)
        worker.stop()
        worker.stop()
        XCTAssertEqual(fixture.cancelledObservations, 1)
        XCTAssertEqual(fixture.cancelledScans, 1)
        worker.start()
        fixture.observations[1](.initial([fixture.stored.any]))
        fixture.observations[0](.delete(fixture.stored.any))
        fixture.scans[0](fixture.advertisement())
        await settle()
        XCTAssertTrue(fixture.updates.isEmpty)
        fixture.scans[1](fixture.advertisement())
        await eventually { fixture.updates.count == 1 }
        worker.stop()
        XCTAssertEqual(fixture.cancelledObservations, 2)
        XCTAssertEqual(fixture.cancelledScans, 2)
    }

    func testSensorChangesKeepOneScanAndDeletingTheLastSensorStopsIt() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.observations[0](.insert(fixture.stored.any))
        fixture.observations[0](.update(fixture.stored.with(name: "Kitchen").any))
        XCTAssertEqual(fixture.scans.count, 1)
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.updates.count == 1 }
        XCTAssertEqual(fixture.updates[0].name, "Kitchen")
        fixture.observations[0](.delete(fixture.stored.any))
        XCTAssertEqual(fixture.cancelledScans, 1)
        fixture.scans[0](fixture.advertisement(version: 7))
        await settle()
        XCTAssertEqual(fixture.updates.count, 1)
        fixture.observations[0](.update(fixture.stored.any))
        XCTAssertEqual(fixture.scans.count, 2)
    }

    func testSuccessfulUpdatesCoalesceAndPreserveTheMappedMACForLegacyPackets() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        let legacy = fixture.advertisement(mac: nil, version: 3)
        for _ in 0..<10 { fixture.scans[0](legacy) }
        await eventually { fixture.finishedUpdates == 1 }
        XCTAssertEqual(fixture.updates.count, 1)
        XCTAssertEqual(fixture.updates[0].macId?.value, fixture.mac)
        XCTAssertEqual(fixture.updates[0].version, 3)
        fixture.scans[0](legacy)
        await settle()
        XCTAssertEqual(fixture.updates.count, 1)
        fixture.scans[0](fixture.advertisement(version: 5))
        await eventually { fixture.finishedUpdates == 2 }
        XCTAssertEqual(fixture.updates[1].version, 5)
    }

    func testInvalidUnrelatedAndUnmappedAdvertisementsCannotChangeSavedSensors() async {
        let fixture = SensorPropertiesFixture()
        fixture.macs.removeAll()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement(luid: ""))
        fixture.scans[0](fixture.advertisement(luid: "unknown", mac: "other"))
        fixture.scans[0](fixture.advertisement(luid: "unknown", mac: nil))
        fixture.scans[0](fixture.advertisement(mac: ""))
        fixture.scans[0](fixture.advertisement(mac: nil, version: 3))
        fixture.scans[0](fixture.advertisement(version: 5))
        await settle()
        XCTAssertTrue(fixture.updates.isEmpty)
        XCTAssertTrue(fixture.reads.isEmpty)
        XCTAssertTrue(fixture.errors.isEmpty)
    }

    func testRemoteSensorDiscoverySavesItsBluetoothPropertiesWithoutLosingCloudMetadata() async {
        let fixture = SensorPropertiesFixture()
        fixture.stored.luid = nil
        fixture.stored.isCloudSensor = true
        fixture.stored.owner = "owner@example.test"
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement())
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.finishedUpdates == 1 }
        XCTAssertTrue(fixture.reads.isEmpty)
        let saved = fixture.updates[0]
        XCTAssertEqual(saved.luid?.value, fixture.luid)
        XCTAssertEqual(saved.macId?.value, fixture.mac)
        XCTAssertEqual(saved.serviceUUID, "service")
        XCTAssertEqual(saved.version, 6)
        XCTAssertEqual(saved.isConnectable, true)
        XCTAssertEqual(saved.isCloudSensor, true)
        XCTAssertEqual(saved.owner, "owner@example.test")
        fixture.scans[0](fixture.advertisement())
        await settle()
        XCTAssertEqual(fixture.updates.count, 1)
    }

    func testChangedBluetoothUUIDReadsTheCurrentRowBeforeSavingAndRetriesFailedReads() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.stored.name = "Renamed in the meantime"
        fixture.readError = .grdb(NSError(domain: "test", code: 1))
        let event = fixture.advertisement(luid: UUID().uuidString)
        fixture.scans[0](event)
        await eventually { fixture.errors.count == 1 }
        XCTAssertTrue(fixture.updates.isEmpty)
        guard case .ruuviPersistence(.grdb) = fixture.errors[0] else { return XCTFail("Expected read error") }
        fixture.readError = nil
        fixture.scans[0](event)
        await eventually { fixture.finishedUpdates == 1 }
        XCTAssertEqual(fixture.reads, [fixture.mac, fixture.mac])
        XCTAssertEqual(fixture.updates[0].name, "Renamed in the meantime")
        XCTAssertEqual(fixture.updates[0].luid?.value, event.luid)
    }

    func testMissingSensorIsRemovedAndOtherErrorsAreReportedOnTheMainThread() async {
        for missingAtRead in [false, true] {
            let fixture = SensorPropertiesFixture()
            let worker = fixture.makeWorker()
            defer { worker.stop() }
            worker.start()
            fixture.observations[0](.initial([fixture.stored.any]))
            fixture.observations[0](.error(.ruuviPersistence(.failedToFindRuuviTag)))
            await eventually { fixture.errors.count == 1 }
            guard case .ruuviReactor = fixture.errors[0] else { return XCTFail("Expected reactor error") }
            fixture.updateError = .ruuviPersistence(.grdb(NSError(domain: "test", code: 2)))
            fixture.scans[0](fixture.advertisement())
            await eventually { fixture.errors.count == 2 }
            guard case .ruuviPool(.ruuviPersistence(.grdb)) = fixture.errors[1]
            else { return XCTFail("Expected pool error") }
            fixture.updateError = .ruuviPersistence(.failedToFindRuuviTag)
            fixture.readError = .failedToFindRuuviTag
            fixture.scans[0](fixture.advertisement(luid: missingAtRead ? "changed" : fixture.luid))
            await eventually { fixture.cancelledScans == 1 }
            fixture.scans[0](fixture.advertisement())
            await settle()
            XCTAssertEqual(fixture.errors.count, 2, "Removed sensors must not keep reporting failures")
            XCTAssertTrue(fixture.reportOnMainThread)
        }
    }

    func testStopDuringUUIDLookupPreventsASubsequentWrite() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        var suspended: CheckedContinuation<Void, Never>?
        fixture.beforeRead = { await withCheckedContinuation { suspended = $0 } }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement(luid: "changed"))
        await eventually { suspended != nil }
        worker.stop()
        suspended?.resume()
        await settle()
        XCTAssertTrue(fixture.updates.isEmpty)
        XCTAssertTrue(fixture.errors.isEmpty)
    }

    func testReleasingAWorkerCancelsInFlightWorkWithoutKeepingItAlive() async {
        let fixture = SensorPropertiesFixture()
        fixture.beforeUpdate = { try? await Task.sleep(for: .seconds(5)) }
        var worker: RuuviTagPropertiesDaemonBTKit? = fixture.makeWorker()
        weak var released = worker
        worker?.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.updates.count == 1 }
        worker = nil
        XCTAssertNil(released)
        await eventually { fixture.cancelledUpdates == 1 }
        XCTAssertEqual(fixture.cancelledScans, 1)
        XCTAssertEqual(fixture.cancelledObservations, 1)
        XCTAssertTrue(fixture.errors.isEmpty)
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(20)) }

    private func eventually(file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Sensor properties did not reach the expected state", file: file, line: line)
    }
}

extension SensorPropertiesLifecycleTests {
    func testReplacingTheSensorSnapshotCancelsWorkForRemovedSensors() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        fixture.beforeUpdate = { try? await Task.sleep(for: .seconds(5)) }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.updates.count == 1 }
        fixture.observations[0](.initial([]))
        await eventually { fixture.cancelledUpdates == 1 }
        XCTAssertEqual(fixture.cancelledScans, 1)
        XCTAssertTrue(fixture.errors.isEmpty)
    }

    func testFalseSaveResultDoesNotCacheUnsavedProperties() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        fixture.updateResult = false
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.finishedUpdates == 1 }
        fixture.updateResult = true
        fixture.scans[0](fixture.advertisement())
        await eventually { fixture.finishedUpdates == 2 }
        fixture.scans[0](fixture.advertisement())
        await settle()
        XCTAssertEqual(fixture.updates.count, 2)
    }

    func testLateCompletionCannotClearAReplacementJobOrRestoreADeletedSensor() async {
        let fixture = SensorPropertiesFixture()
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        var suspended = [CheckedContinuation<Void, Never>]()
        fixture.beforeUpdate = { await withCheckedContinuation { suspended.append($0) } }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement())
        await eventually { suspended.count == 1 }
        worker.stop()
        worker.start()
        fixture.observations[1](.initial([fixture.stored.any]))
        fixture.scans[1](fixture.advertisement())
        await eventually { suspended.count == 2 }
        guard suspended.count == 2 else { suspended.forEach { $0.resume() }; return }
        suspended[0].resume()
        await eventually { fixture.finishedUpdates == 1 }
        fixture.scans[1](fixture.advertisement())
        await settle()
        XCTAssertEqual(fixture.updates.count, 2)
        fixture.observations[1](.delete(fixture.stored.any))
        suspended[1].resume()
        await eventually { fixture.finishedUpdates == 2 }
        fixture.scans[1](fixture.advertisement())
        await settle()
        XCTAssertEqual(fixture.updates.count, 2)
        XCTAssertEqual(fixture.cancelledUpdates, 2)
    }
}
