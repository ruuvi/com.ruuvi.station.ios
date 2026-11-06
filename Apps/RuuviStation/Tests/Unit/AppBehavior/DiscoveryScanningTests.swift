import BTKit
import XCTest
@testable import RuuviDiscover
@testable import station

@MainActor final class DiscoveryScanningTests: XCTestCase {
    func testNearbySensorsAreSortedBySignalAndRemovedWhenLost() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        XCTAssertTrue(fixture.view.isBluetoothEnabled)
        XCTAssertTrue(fixture.view.isCloseEnabled)
        let weak = fixture.packet(mac: "AA:BB:CC:DD:EE:01", rssi: -90)
        let strong = fixture.packet(mac: "AA:BB:CC:DD:EE:02", rssi: -30)
        fixture.emit(weak); fixture.emit(strong)
        await waitForAppState("nearby sensors") { fixture.view.ruuviTags.count == 2 }
        XCTAssertEqual(fixture.view.ruuviTags.map(\.mac), [strong.mac, weak.mac])
        fixture.bluetooth.lost.last?(strong)
        await waitForAppState("lost sensor removed") { fixture.view.ruuviTags.count == 1 }
        XCTAssertEqual(fixture.view.ruuviTags.first?.mac, weak.mac)
    }

    func testLegacySensorsWithoutMacAddressesKeepTheirDistinctBluetoothIdentities() async {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let first = fixture.legacyPacket()
        let second = fixture.legacyPacket()
        fixture.emit(first); fixture.emit(second)
        await waitForAppState("two legacy sensors") { fixture.view.ruuviTags.count == 2 }
        XCTAssertEqual(Set(fixture.view.ruuviTags.compactMap { $0.luid?.value }), [first.uuid, second.uuid])
    }

    func testChangingAdvertisementFormatReplacesTheOldDeviceInsteadOfDuplicatingIt() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let uuid = UUID().uuidString
        fixture.emit(fixture.legacyPacket(uuid: uuid))
        await waitForAppState("legacy nearby sensor") { fixture.view.ruuviTags.count == 1 }
        XCTAssertNil(fixture.view.ruuviTags[0].mac)
        fixture.emit(fixture.packet(uuid: uuid))
        await waitForAppState("upgraded advertisement") { fixture.view.ruuviTags.first?.mac != nil }
        XCTAssertEqual(fixture.view.ruuviTags.count, 1)
        fixture.presenter.viewDidChoose(device: fixture.view.ruuviTags[0], displayName: "Office")
        await waitForAppState("selected sensor added") { fixture.output.added.count == 1 }
        XCTAssertEqual(fixture.ownership.additions[0].0.name, "Office")
        XCTAssertEqual(fixture.ownership.additions[0].1?.source, .advertisement)
    }

    func testPersistedSensorsAreHiddenByEitherLocalIdentityOrMacEvenAfterTheLocalIdentityChanges() async {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        var saved = fixture.sensorData.sensor("Already added", version: 5)
        saved.macId = "AA:BB:CC:DD:EE:FF".mac
        await fixture.start([saved.any])
        fixture.emit(fixture.packet(uuid: UUID().uuidString, mac: saved.macId!.value))
        let new = fixture.packet(mac: "AA:BB:CC:DD:EE:01")
        fixture.emit(new)
        await waitForAppState("new sensor visible") { fixture.view.ruuviTags.contains { $0.mac == new.mac } }
        XCTAssertEqual(fixture.view.ruuviTags.map(\.mac), [new.mac])
        fixture.send(.delete(saved.any))
        await waitForAppState("removed sensor becomes discoverable") { fixture.view.ruuviTags.count == 2 }
        fixture.send(.insert(saved.any))
        await waitForAppState("added sensor hidden again") { fixture.view.ruuviTags.count == 1 }
    }

    func testBluetoothUnavailableStatesClearTheListAndExplainWhetherPermissionWasDenied() async {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        for state: BTScannerState in [.poweredOff, .unsupported, .unauthorized] {
            fixture.emit(fixture.packet())
            await waitForAppState("sensor before Bluetooth state change") { !fixture.view.ruuviTags.isEmpty }
            fixture.bluetooth.setState(state)
            await waitForAppState("Bluetooth state applied") { fixture.view.ruuviTags.isEmpty }
            XCTAssertFalse(fixture.view.isBluetoothEnabled)
            XCTAssertEqual(fixture.view.bluetoothDialogs.last, state == .unauthorized)
        }
        fixture.bluetooth.setState(.poweredOn)
        XCTAssertTrue(fixture.view.isBluetoothEnabled)
        fixture.presenter.viewDidTriggerDisabledBTRow()
        XCTAssertEqual(fixture.view.bluetoothDialogs.last, false)
    }

    func testDeniedSystemPermissionRemainsVisibleEvenIfBluetoothIsPoweredOn() async {
        let fixture = DiscoveryFixture(permissionGranted: false)
        defer { fixture.cleanup() }
        await fixture.start()
        fixture.bluetooth.setState(.poweredOn)
        XCTAssertEqual(fixture.view.bluetoothDialogs.last, true)
        fixture.presenter.viewDidTriggerDisabledBTRow()
        XCTAssertEqual(fixture.view.bluetoothDialogs.last, true)
        fixture.presenter.viewDidTriggerClose()
        fixture.presenter.viewDidTapUseNFC()
        XCTAssertEqual(fixture.output.closes, 1)
        XCTAssertEqual(fixture.view.nfcStarts, 1)
    }

    func testRepeatedAppearancesCancelPreviousObservationsAndLateCallbacksCannotReappear() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let oldScan = try XCTUnwrap(fixture.bluetooth.scans.first)
        fixture.presenter.viewWillAppear()
        XCTAssertEqual(Set(fixture.bluetooth.cancellations), ["scan", "state", "lost"])
        let current = fixture.packet(mac: "AA:BB:CC:DD:EE:01")
        fixture.emit(current)
        oldScan(fixture.packet(mac: "AA:BB:CC:DD:EE:02"))
        await waitForAppState("current scan shown") { fixture.view.ruuviTags.contains { $0.mac == current.mac } }
        XCTAssertEqual(fixture.view.ruuviTags.map(\.mac), [current.mac])
        fixture.presenter.viewWillDisappear()
        fixture.bluetooth.states.last?(.poweredOff)
        XCTAssertTrue(fixture.view.isBluetoothEnabled)
    }

    func testLegacySensorSelectionRequestsFirmwareUpgradeWithoutAddingAnIncompleteSensor() async throws {
        let fixture = DiscoveryFixture()
        defer { fixture.cleanup() }
        await fixture.start()
        let packet = fixture.legacyPacket()
        fixture.emit(packet)
        await waitForAppState("legacy sensor shown") { fixture.view.ruuviTags.count == 1 }
        fixture.presenter.viewDidChoose(device: fixture.view.ruuviTags[0], displayName: "Old sensor")
        XCTAssertEqual(fixture.view.upgradeDialogs, [packet.uuid])
        XCTAssertTrue(fixture.ownership.additions.isEmpty)
    }
}
