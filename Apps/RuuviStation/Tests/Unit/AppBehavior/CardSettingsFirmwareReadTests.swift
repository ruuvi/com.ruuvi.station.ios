import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardSettingsFirmwareReadTests: XCTestCase {
    func testFirmwareReadPreservesNewerMetadataAndDuplicateStartsShareThePendingRequest() async throws {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.snapshot.displayData.firmwareVersion = nil
        let pool = fixture.services.data.pool
        pool.allowSensorUpdates = true
        var latest = fixture.measurements.sensor
        latest.name = "Renamed while reading firmware"
        fixture.measurements.storage.oneSensors = [fixture.sensor.id: latest.any]
        var callbacks = [(Result<String, Error>) -> Void]()
        fixture.presenter.readFirmwareRevision = { uuid, completion in
            XCTAssertEqual(uuid, fixture.sensor.luid?.value)
            callbacks.append(completion)
        }
        defer { fixture.presenter.readFirmwareRevision = nil }
        fixture.presenter.start()
        fixture.presenter.start()
        XCTAssertEqual(callbacks.count, 1)
        XCTAssertEqual(fixture.view.freezes, 1)
        callbacks[0](.success("1.4.0"))
        await waitForAppState("settings firmware persisted") { fixture.view.unfreezes == 1 }
        let updated = try XCTUnwrap(pool.updatedSensors.last)
        XCTAssertEqual(updated.name, latest.name)
        XCTAssertEqual(updated.firmwareVersion, "1.4.0")
        XCTAssertEqual(updated.id, fixture.sensor.id)
    }

    func testClosingOrReconfiguringRejectsLateFirmwareResultsAndAllowsTheNextRead() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.snapshot.displayData.firmwareVersion = nil
        fixture.measurements.storage.oneSensors = [fixture.sensor.id: fixture.sensor]
        fixture.services.data.pool.allowSensorUpdates = true
        var callbacks = [(Result<String, Error>) -> Void]()
        fixture.presenter.readFirmwareRevision = { _, completion in callbacks.append(completion) }
        fixture.presenter.start()
        fixture.presenter.stop()
        callbacks[0](.success("old closed result"))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.services.data.pool.updatedSensors.isEmpty)
        XCTAssertEqual(fixture.view.unfreezes, 1)
        fixture.presenter.start()
        fixture.configure()
        fixture.presenter.start()
        XCTAssertEqual(callbacks.count, 3)
        callbacks[1](.success("superseded result"))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.services.data.pool.updatedSensors.isEmpty)
        callbacks[2](.success("1.5.0"))
        await waitForAppState("current firmware completes") { fixture.view.unfreezes == 3 }
        XCTAssertEqual(fixture.services.data.pool.updatedSensors.map(\.firmwareVersion), ["1.5.0"])
    }

    func testReadOrPersistenceFailureRestoresTheConnectionDisplayAndCanRetry() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.snapshot.displayData.firmwareVersion = nil
        fixture.measurements.storage.oneSensors = [:]
        var callbacks = [(Result<String, Error>) -> Void]()
        fixture.presenter.readFirmwareRevision = { _, completion in callbacks.append(completion) }
        fixture.presenter.start()
        callbacks[0](.failure(NSError(domain: "Firmware", code: 1)))
        await waitForAppState("failed read unfreezes") { fixture.view.unfreezes == 1 }
        XCTAssertTrue(fixture.services.data.pool.updatedSensors.isEmpty)
        fixture.presenter.start()
        callbacks[1](.success("1.6.0"))
        await waitForAppState("failed persistence unfreezes") { fixture.view.unfreezes == 2 }
        XCTAssertEqual(fixture.services.data.pool.updatedSensors.first?.id, fixture.sensor.id)
        XCTAssertEqual(fixture.services.data.pool.updatedSensors.first?.firmwareVersion, "1.6.0")
    }

    func testACloudOnlySensorNeverRequestsBluetoothFirmware() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        var sensor = fixture.measurements.sensor
        sensor.luid = nil
        fixture.sensor = sensor.any
        fixture.snapshot.displayData.firmwareVersion = nil
        fixture.configure()
        fixture.presenter.readFirmwareRevision = { _, _ in XCTFail("Cloud-only sensor requested Bluetooth firmware") }
        fixture.presenter.start()
        XCTAssertEqual(fixture.view.freezes, 0)
        await flushAppBindings()
    }
}
