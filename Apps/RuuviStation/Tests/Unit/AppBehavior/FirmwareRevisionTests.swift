import Combine
import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class FirmwareRevisionTests: XCTestCase {
    func testRevisionReadIsLazyAndUpdatesTheFreshSensorWithoutOverwritingItsMetadata() async throws {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        let publisher = interactor.serveCurrentRelease(for: fixture.sensor)
        XCTAssertTrue(fixture.reads.isEmpty)
        var versions = [String]()
        let token = publisher.sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
            }, receiveValue: { versions.append($0.version) })
        await waitForAppState("firmware revision read") { fixture.reads.count == 1 }
        var fresh = fixture.sensor
        fresh.name = "Renamed during firmware check"
        fresh.owner = "new@example.com"
        fixture.measurements.storage.oneSensors = [fresh.id: fresh.any]
        fixture.reads[0].1(.success("3.31.1"))
        await waitForAppState("firmware version persisted") { fixture.pool.updatedSensors.count == 1 }
        XCTAssertEqual(versions, ["3.31.1"])
        XCTAssertEqual(fixture.pool.updatedSensors[0].name, fresh.name)
        XCTAssertEqual(fixture.pool.updatedSensors[0].owner, fresh.owner)
        XCTAssertEqual(fixture.pool.updatedSensors[0].firmwareVersion, "3.31.1")
        withExtendedLifetime(token) {}
    }

    func testEquivalentFirmwareDisplayVersionDoesNotWriteTheSensorAgain() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        fixture.sensor.firmwareVersion = "3.31.1"
        let interactor = fixture.interactor()
        var versions = [String]()
        let token = interactor.serveCurrentRelease(for: fixture.sensor).sink(
            receiveCompletion: { _ in },
            receiveValue: { versions.append($0.version) })
        await waitForAppState("firmware read") { fixture.reads.count == 1 }
        fixture.reads[0].1(.success("3.31.1+0"))
        await waitForAppState("firmware read complete") { versions.count == 1 }
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
        withExtendedLifetime(token) {}
    }

    func testMissingLocalIdentityAndBluetoothErrorsFailWithoutPersistingAnything() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        var missing = fixture.sensor
        missing.luid = nil
        var failures = [Error]()
        let missingToken = interactor.serveCurrentRelease(for: missing).sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { failures.append(error) }
            }, receiveValue: { _ in XCTFail("Missing identity produced firmware") })
        XCTAssertEqual(failures.first as? station.DFUError, .failedToGetLuid)
        XCTAssertTrue(fixture.reads.isEmpty)
        let failedToken = interactor.serveCurrentRelease(for: fixture.sensor).sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { failures.append(error) }
            }, receiveValue: { _ in XCTFail("Failed Bluetooth read produced firmware") })
        await waitForAppState("Bluetooth read started") { fixture.reads.count == 1 }
        fixture.reads[0].1(.failure(NSError(domain: "FirmwareTests", code: 17)))
        await waitForAppState("Bluetooth read failure") { failures.count == 2 }
        XCTAssertEqual((failures.last as NSError?)?.code, 17)
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
        withExtendedLifetime((missingToken, failedToken)) {}
    }

    func testConcurrentRevisionReadsKeepIndependentTimeoutsAndIgnoreLateResults() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor(timeout: 0.04)
        var failures = 0
        var versions = [String]()
        let first = interactor.serveCurrentRelease(for: fixture.sensor).sink(
            receiveCompletion: {
                if case .failure = $0 { failures += 1 }
            }, receiveValue: { _ in XCTFail("Timed out read produced a value") })
        let second = interactor.serveCurrentRelease(for: fixture.sensor).sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
            }, receiveValue: { versions.append($0.version) })
        await waitForAppState("independent firmware reads") { fixture.reads.count == 2 }
        fixture.reads[1].1(.success("3.31.1"))
        await waitForAppState("first read timed out") { failures == 1 && versions.count == 1 }
        await waitForAppState("successful read persisted") { fixture.pool.updatedSensors.count == 1 }
        fixture.reads[0].1(.success("9.0.0"))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.pool.updatedSensors.count, 1)
        withExtendedLifetime((first, second)) {}
    }

    func testCancelledRevisionReadCannotLaterUpdateStoredFirmware() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        let token = interactor.serveCurrentRelease(for: fixture.sensor).sink(
            receiveCompletion: { _ in XCTFail("Cancelled read completed") },
            receiveValue: { _ in XCTFail("Cancelled read emitted a version") })
        await waitForAppState("read before cancellation") { fixture.reads.count == 1 }
        token.cancel()
        fixture.reads[0].1(.success("9.0.0"))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
    }
}
