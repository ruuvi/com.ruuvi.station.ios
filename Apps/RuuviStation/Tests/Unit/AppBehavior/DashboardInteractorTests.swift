import Foundation
import RuuviOntology
import RuuviService
import XCTest
@testable import station

@MainActor final class DashboardInteractorTests: XCTestCase {
    func testKnownFirmwareSkipsBluetoothAndAnUnownedResponseSetsTheCooldownAndNotifies() async {
        let fixture = DashboardInteractorFixture()
        defer { fixture.cleanup() }
        fixture.sensor.firmwareVersion = "3.31.1"
        fixture.saveSensor()
        fixture.interactor.ownerCheckDelay = 0.001
        let notified = expectation(description: "Unowned sensor notification")
        let token = NotificationCenter.default.addObserver(
            forName: .RuuviTagOwnershipCheckDidEnd, object: nil, queue: .main
        ) {
            XCTAssertEqual($0.userInfo?[RuuviTagOwnershipCheckResultKey.hasOwner] as? Bool, false)
            notified.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }
        fixture.start()
        await fulfillment(of: [notified], timeout: 2)
        XCTAssertTrue(fixture.firmwareRequests.isEmpty)
        XCTAssertEqual(fixture.ownership.ownerChecks, [fixture.sensor.macId!.value])
        XCTAssertNotNil(fixture.measurements.settings.ownerCheckDate(for: fixture.sensor.macId))
        fixture.start()
        await flushAppBindings(); await flushAppBindings()
        XCTAssertEqual(fixture.ownership.ownerChecks.count, 1)
    }

    func testFirmwareAndOwnershipWritesPreserveNewMetadataAndNormalizeTheCurrentEmail() async {
        let fixture = DashboardInteractorFixture()
        defer { fixture.cleanup() }
        fixture.user.email = "OWNER@EXAMPLE.COM"
        fixture.ownership.ownerResult = ("Owner@Example.com", nil)
        fixture.start()
        await waitForAppState("firmware request") { fixture.firmwareRequests.count == 1 }
        fixture.sensor.name = "Renamed while reading firmware"
        fixture.saveSensor()
        fixture.firmwareCompletion?(.success("3.31.2"))
        await waitForAppState("firmware and owner saved") { fixture.pool.updatedSensors.count == 2 }
        XCTAssertEqual(fixture.pool.updatedSensors.first?.firmwareVersion, "3.31.2")
        let updated = fixture.pool.updatedSensors.last
        XCTAssertEqual(updated?.name, "Renamed while reading firmware")
        XCTAssertEqual(updated?.firmwareVersion, "3.31.2")
        XCTAssertEqual(updated?.owner, "owner@example.com")
        XCTAssertTrue(updated?.isOwner == true)
    }

    func testConcurrentRequestsShareOneFirmwareReadAndOneOwnerLookup() async {
        let fixture = DashboardInteractorFixture()
        defer { fixture.cleanup() }
        fixture.start(); fixture.start()
        await waitForAppState("single firmware request") { !fixture.firmwareRequests.isEmpty }
        await flushAppBindings()
        XCTAssertEqual(fixture.firmwareRequests, [fixture.sensor.luid!.value])
        fixture.firmwareCompletion?(.success("3.31.1"))
        await waitForAppState("single owner lookup") { fixture.ownership.ownerChecks.count == 1 }
        await flushAppBindings()
        XCTAssertEqual(fixture.pool.updatedSensors.count, 1)
        XCTAssertEqual(fixture.ownership.ownerChecks.count, 1)
    }

    func testFailedBluetoothAndOwnerRequestsDoNotPreventALaterRetry() async {
        let fixture = DashboardInteractorFixture()
        defer { fixture.cleanup() }
        fixture.ownership.ownerFailure = .failedToParseNetworkResponse
        fixture.start()
        await waitForAppState("first firmware request") { fixture.firmwareRequests.count == 1 }
        fixture.firmwareCompletion?(.failure(NSError(domain: "Bluetooth", code: 1)))
        await waitForAppState("failed owner lookup") { fixture.ownership.ownerChecks.count == 1 }
        await flushAppBindings()
        XCTAssertNil(fixture.measurements.settings.ownerCheckDate(for: fixture.sensor.macId))
        fixture.start()
        await waitForAppState("retry firmware") { fixture.firmwareRequests.count == 2 }
        fixture.ownership.ownerFailure = nil
        fixture.firmwareCompletion?(.failure(NSError(domain: "Bluetooth", code: 1)))
        await waitForAppState("retry owner") { fixture.ownership.ownerChecks.count == 2 }
        XCTAssertTrue(fixture.pool.updatedSensors.isEmpty)
    }

    func testCloudOnlySensorAndUnavailableStorageStillAllowAnOwnerLookup() async {
        let fixture = DashboardInteractorFixture()
        defer { fixture.cleanup() }
        fixture.sensor.luid = nil
        fixture.interactor.ruuviStorage = nil
        fixture.start()
        await waitForAppState("cloud sensor owner") { fixture.ownership.ownerChecks.count == 1 }
        XCTAssertTrue(fixture.firmwareRequests.isEmpty)
        XCTAssertEqual(fixture.ownership.ownerChecks, [fixture.sensor.macId!.value])
    }

    func testKnownOwnerMissingMacAndRecentChecksSuppressUnnecessaryRequests() async {
        for mode in 0..<3 {
            let fixture = DashboardInteractorFixture()
            defer { fixture.cleanup() }
            fixture.sensor.firmwareVersion = "3.31.1"
            if mode == 0 { fixture.sensor.owner = "person@example.com" }
            if mode == 1 { fixture.sensor.macId = nil }
            if mode == 2 { fixture.measurements.settings.setOwnerCheckDate(for: fixture.sensor.macId, value: Date()) }
            fixture.saveSensor()
            fixture.start()
            await waitForAppState("stored sensor read") { !fixture.measurements.storage.oneReads.isEmpty }
            await flushAppBindings(); await flushAppBindings()
            XCTAssertTrue(fixture.firmwareRequests.isEmpty)
            XCTAssertTrue(fixture.ownership.ownerChecks.isEmpty)
        }
    }
}
