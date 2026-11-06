import CoreNFC
import RuuviOntology
import XCTest
@testable import RuuviDiscover
@testable import station

@MainActor final class DiscoveryNFCTests: XCTestCase {
    func testNfcParsesNullTerminatedFieldsAndAddsAnOfflineSensorWithUnknownDataFormat() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.presenter.viewDidReceiveNFCMessages(messages: [
            fixture.nfc(mac: "AA:BB:CC:DD:EE:FF\0", firmware: "3.31.1\0", id: "secret\0")
        ])
        let details = try XCTUnwrap(fixture.view.details.last)
        XCTAssertEqual(details.sensor?.macId, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(details.sensor?.id, "secret")
        XCTAssertTrue(details.add)
        XCTAssertFalse(details.go)
        XCTAssertFalse(details.upgrade)
        XCTAssertTrue(details.message.contains("3.31.1"))
        fixture.presenter.viewDidAddDeviceWithNFC(with: details.sensor)
        await waitForAppState("offline NFC sensor added") { fixture.output.added.count == 1 }
        let sensor = fixture.output.added[0]
        XCTAssertEqual(sensor.version, 0)
        XCTAssertEqual(sensor.macId?.value, "AA:BB:CC:DD:EE:FF")
        XCTAssertNil(sensor.luid)
        XCTAssertFalse(sensor.isConnectable)
        XCTAssertEqual(sensor.firmwareVersion, "3.31.1")
        XCTAssertNil(fixture.ownership.additions[0].1)
    }

    func testNfcUsesTheNearbyBluetoothRecordAndSanitizesItsFirmwareVersion() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let packet = fixture.packet()
        fixture.emit(packet)
        await waitForAppState("Bluetooth sensor discovered") { fixture.view.ruuviTags.count == 1 }
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.nfc(firmware: "3.31.1+0")])
        let details = try XCTUnwrap(fixture.view.details.last)
        XCTAssertTrue(details.add)
        fixture.presenter.viewDidAddDeviceWithNFC(with: details.sensor)
        await waitForAppState("NFC Bluetooth sensor added") { fixture.output.added.count == 1 }
        XCTAssertEqual(fixture.output.added[0].luid?.value, packet.uuid)
        XCTAssertEqual(fixture.output.added[0].version, 5)
        XCTAssertEqual(fixture.output.added[0].firmwareVersion, "3.31.1")
        XCTAssertEqual(fixture.ownership.additions[0].1?.temperature?.value, 20)
    }

    func testSavedNfcSensorUsesItsCurrentNameAndNavigatesToItAfterMetadataChanges() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        var sensor = fixture.sensorData.sensor("Old name")
        sensor.macId = "AA:BB:CC:DD:EE:FF".mac
        await fixture.start([sensor.any])
        sensor.name = "Kitchen"
        fixture.send(.update(sensor.any))
        await flushAppBindings(); await flushAppBindings()
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.nfc()])
        let details = try XCTUnwrap(fixture.view.details.last)
        XCTAssertFalse(details.add)
        XCTAssertTrue(details.go)
        XCTAssertTrue(details.message.contains("Kitchen"))
        fixture.presenter.viewDidGoToSensor(with: details.sensor)
        XCTAssertEqual(fixture.output.selected.last?.name, "Kitchen")
        XCTAssertTrue(fixture.ownership.additions.isEmpty)
    }

    func testLegacyNfcOffersFirmwareUpgradeAndAirNfcUsesTheAirName() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.nfc(firmware: "2.5.9")])
        var details = try XCTUnwrap(fixture.view.details.last)
        XCTAssertTrue(details.upgrade)
        XCTAssertTrue(details.legacy)
        XCTAssertFalse(details.add)
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.nfc(firmware: "Ruuvi Air 1.0.0")])
        details = try XCTUnwrap(fixture.view.details.last)
        XCTAssertTrue(details.message.contains("Ruuvi Air"))
        XCTAssertTrue(details.add)
        XCTAssertFalse(details.legacy)
        fixture.presenter.viewDidAddDeviceWithNFC(with: details.sensor)
        await waitForAppState("Air NFC added") { fixture.output.added.count == 1 }
        XCTAssertTrue(fixture.output.added[0].name.contains("Ruuvi Air"))
    }

    func testInvalidNfcSelectionsDoNotWriteAndOwnershipFailuresAreVisible() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.presenter.viewDidAddDeviceWithNFC(with: nil)
        fixture.presenter.viewDidAddDeviceWithNFC(with: NFCSensor(id: "", macId: "", firmwareVersion: ""))
        await flushAppBindings()
        XCTAssertTrue(fixture.ownership.additions.isEmpty)
        fixture.ownership.addFailure = .failedToParseNetworkResponse
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.nfc()])
        fixture.presenter.viewDidAddDeviceWithNFC(with: fixture.view.details.last?.sensor)
        await waitForAppState("NFC add error") { !fixture.errors.errors.isEmpty }
        XCTAssertTrue(fixture.output.added.isEmpty)
    }
}
