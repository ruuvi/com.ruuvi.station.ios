import Foundation
import RuuviOntology
import RuuviPool
import XCTest
@testable import RuuviDaemon
@testable import station

@MainActor final class AdvertisementPersistenceTests: XCTestCase {
    func testForegroundPacketsPersistHistoryLatestAndRawWidgetMeasurementsOncePerSequence() async throws {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit(fixture.packet(sequence: 65_535))
        await waitForAppState("first latest record") { fixture.pool.createdLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        let record = try XCTUnwrap(fixture.cache.snapshot(matching: fixture.sensor.id)?.record)
        XCTAssertEqual(record.temperature, 20)
        XCTAssertEqual(record.humidity, 0.5)
        XCTAssertEqual(record.pressure, 1000)
        XCTAssertEqual(record.voltage, 3)
        XCTAssertEqual(record.measurementSequenceNumber, 65_535)
        fixture.emit(fixture.packet(sequence: 65_535))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        fixture.emit(fixture.packet(sequence: 0))
        await waitForAppState("wrapped sequence persisted") { fixture.pool.updatedLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
        XCTAssertEqual(fixture.pool.updatedLatest.last?.measurementSequenceNumber, 0)
        XCTAssertEqual(fixture.pool.updatedLatest.last?.macId?.value, fixture.sensor.macId?.value)
    }

    func testPacketsWithoutASequenceAreNotAccidentallyDeduplicated() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit(fixture.packet(sequence: nil))
        await waitForAppState("first unsequenced record") { fixture.pool.createdLatest.count == 1 }
        fixture.emit(fixture.packet(sequence: nil))
        await waitForAppState("second unsequenced record") { fixture.pool.updatedLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testBackgroundSamplingUsesTheConfiguredIntervalInsteadOfEveryAdvertisement() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.appIsOnForeground = false
        await fixture.start()
        fixture.emit(fixture.packet(sequence: 1))
        await waitForAppState("background record") { fixture.pool.createdLatest.count == 1 }
        fixture.emit(fixture.packet(sequence: 2))
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.pool.createdRecords.count, 1)
        fixture.measurements.settings.advertisementDaemonIntervalMinutes = 0
        fixture.emit(fixture.packet(sequence: 3))
        await waitForAppState("zero interval record") { fixture.pool.updatedLatest.count == 1 }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testLegacyAirAdvertisementsUpdateLatestWithoutAddingIncompleteHistoryRecords() async throws {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit(try fixture.airPacket())
        await waitForAppState("legacy Air latest") { fixture.pool.createdLatest.count == 1 }
        XCTAssertTrue(fixture.pool.createdRecords.isEmpty)
        XCTAssertEqual(fixture.pool.createdLatest.first?.version, 6)
        XCTAssertEqual(fixture.cache.snapshot(matching: fixture.sensor.id)?.record?.version, 6)
    }

    func testCalibrationChangeRefreshesTheWidgetEvenWhenTheDeviceSequenceHasNotChanged() async throws {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.emit(fixture.packet())
        await waitForAppState("initial record") { fixture.pool.createdLatest.count == 1 }
        let calibration = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId, temperatureOffset: 2,
            humidityOffset: 0.1, pressureOffset: 3)
        fixture.reactor.sendSettings(fixture.sensor, .update(calibration))
        await flushAppBindings(); await flushAppBindings()
        fixture.emit(fixture.packet())
        await waitForAppState("calibration applied to widget") {
            fixture.cache.snapshot(matching: fixture.sensor.id)?.settings?.temperatureOffset == 2
        }
        XCTAssertEqual(fixture.pool.createdRecords.count, 2)
    }

    func testMissingSensorFailureStopsItsObservationAndRemovesItsWidgetEntry() async {
        let fixture = AdvertisementFixture()
        defer { fixture.cleanup() }
        fixture.pool.recordFailure = .ruuviPersistence(.failedToFindRuuviTag)
        await fixture.start()
        fixture.emit(fixture.packet())
        await waitForAppState("deleted sensor scan cancelled") { fixture.cancellations.count == 1 }
        XCTAssertNil(fixture.cache.snapshot(matching: fixture.sensor.id))
        XCTAssertTrue(fixture.pool.createdLatest.isEmpty)
    }
}
