@testable import RuuviDaemonRuuviTag
import XCTest

final class AdvertisementPersistenceGateTests: XCTestCase {
    func testMetadataUpdateInvalidatesCapturedSensorAndSettings() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor", "other"])
        let generation = try XCTUnwrap(gate.generation(for: "sensor"))
        let otherGeneration = gate.generation(for: "other")
        var widgetName = "Old name"
        var widgetOffset = 1

        gate.invalidate(sensorID: "sensor")
        widgetName = "New name"
        widgetOffset = 2
        gate.performIfValid(sensorID: "sensor", generation: generation) {
            widgetName = "Old name"
            widgetOffset = 1
        }

        XCTAssertEqual(widgetName, "New name")
        XCTAssertEqual(widgetOffset, 2)
        XCTAssertNotEqual(gate.generation(for: "sensor"), generation)
        XCTAssertEqual(gate.generation(for: "other"), otherGeneration)
    }

    func testQueuedAdvertisementCannotRestoreRemovedWidgetOrWriteRecords() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor"])
        let generation = try XCTUnwrap(gate.generation(for: "sensor"))
        var widgetIDs: Set<String> = ["sensor"]
        var recordsWritten = 0

        gate.syncSensors([]) { widgetIDs.removeAll() }
        gate.performIfValid(sensorID: "sensor", generation: generation) {
            widgetIDs.insert("sensor")
            recordsWritten += 1
        }

        XCTAssertTrue(widgetIDs.isEmpty)
        XCTAssertEqual(recordsWritten, 0)
    }

    func testReaddingSensorDoesNotReviveOldAdvertisementOrContinuation() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor"])
        let oldGeneration = try XCTUnwrap(gate.generation(for: "sensor"))
        gate.syncSensors([])
        gate.syncSensors(["sensor"])
        let newGeneration = try XCTUnwrap(gate.generation(for: "sensor"))
        var writes = 0

        gate.performIfValid(sensorID: "sensor", generation: oldGeneration) { writes += 1 }
        gate.performIfValid(sensorID: "sensor", generation: newGeneration) { writes += 1 }

        XCTAssertNotEqual(oldGeneration, newGeneration)
        XCTAssertEqual(writes, 1)
    }

    func testUpdatingSensorListKeepsUnchangedSensorsAdvertisementsValid() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor", "other"])
        let generation = try XCTUnwrap(gate.generation(for: "sensor"))
        gate.syncSensors(["sensor", "new"])
        var writes = 0

        gate.performIfValid(sensorID: "sensor", generation: generation) { writes += 1 }

        XCTAssertEqual(writes, 1)
        XCTAssertNil(gate.generation(for: "other"))
    }

    func testSynchronousContinuationCanValidateAgain() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor"])
        let generation = try XCTUnwrap(gate.generation(for: "sensor"))
        var writes = 0

        gate.performIfValid(sensorID: "sensor", generation: generation) {
            gate.performIfValid(sensorID: "sensor", generation: generation) { writes += 1 }
        }

        XCTAssertEqual(writes, 1)
    }

    func testRemovalWaitsForValidatedWriteBeforeClearingCache() throws {
        let gate = AdvertisementPersistenceGate()
        gate.syncSensors(["sensor"])
        let generation = try XCTUnwrap(gate.generation(for: "sensor"))
        let writeStarted = DispatchSemaphore(value: 0)
        let finishWrite = DispatchSemaphore(value: 0)
        let removalStarted = DispatchSemaphore(value: 0)
        let removalFinished = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            gate.performIfValid(sensorID: "sensor", generation: generation) {
                writeStarted.signal()
                _ = finishWrite.wait(timeout: .now() + 2)
            }
        }
        XCTAssertEqual(writeStarted.wait(timeout: .now() + 1), .success)
        defer { finishWrite.signal() }
        DispatchQueue.global().async {
            removalStarted.signal()
            gate.syncSensors([])
            removalFinished.signal()
        }
        XCTAssertEqual(removalStarted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(removalFinished.wait(timeout: .now() + 0.05), .timedOut)
        finishWrite.signal()
        XCTAssertEqual(removalFinished.wait(timeout: .now() + 1), .success)
        XCTAssertNil(gate.generation(for: "sensor"))
    }
}
