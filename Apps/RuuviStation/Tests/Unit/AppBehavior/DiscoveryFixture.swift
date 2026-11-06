import BTKit
import CoreNFC
import Foundation
import RuuviOntology
import RuuviReactor
import UIKit
import XCTest
@testable import RuuviDiscover
@testable import station

@MainActor final class DiscoveryFixture {
    let view = DiscoveryViewSpy()
    let bluetooth = DiscoveryTransportSpy()
    let reactor = AppTestReactor()
    let ownership = ShareOwnershipSpy()
    let output = DiscoveryOutputSpy()
    let errors = OffsetErrorSpy()
    let sensorData = SensorDataFixture()
    let presenter: DiscoverPresenter
    init(permissionGranted: Bool = true) {
        presenter = DiscoverPresenter(
            view: view, transport: bluetooth, reloadInterval: 0.02,
            initialReloadDelay: 0.01, permissionGranted: { permissionGranted })
        presenter.ruuviReactor = reactor
        presenter.ruuviOwnershipService = ownership
        presenter.output = output
        presenter.errorPresenter = errors
        ownership.allowAdds = true
    }
    func start(_ sensors: [AnyRuuviTagSensor] = []) async {
        presenter.viewDidLoad()
        Array(reactor.sensors.values).forEach { $0(.initial(sensors)) }
        presenter.viewWillAppear()
        await flushAppBindings(); await flushAppBindings()
    }
    func send(_ change: RuuviReactorChange<AnyRuuviTagSensor>) {
        Array(reactor.sensors.values).forEach { $0(change) }
    }
    func packet(uuid: String = UUID().uuidString, mac: String = "AA:BB:CC:DD:EE:FF", rssi: Int = -55) -> RuuviTag {
        .v5(
            .init(
                uuid: uuid, rssi: rssi, isConnectable: true, version: 5, humidity: 50,
                temperature: 20, pressure: 1000, accelerationX: 0, accelerationY: 0, accelerationZ: 1,
                voltage: 3, movementCounter: 12, measurementSequenceNumber: 1, txPower: 4, mac: mac))
    }
    func legacyPacket(uuid: String = UUID().uuidString) -> RuuviTag {
        .v3(
            .init(
                uuid: uuid, rssi: -55, isConnectable: true, version: 3, humidity: 50,
                temperature: 20, pressure: 1000, accelerationX: 0, accelerationY: 0, accelerationZ: 1, voltage: 3))
    }
    func nfc(mac: String = "AA:BB:CC:DD:EE:FF", firmware: String = "3.31.1", id: String = "secret") -> NFCNDEFMessage {
        NFCNDEFMessage(
            records: [("idID", id), ("adMAC", mac), ("swSW", firmware)].map { key, value in
                NFCNDEFPayload(
                    format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(),
                    payload: Data([0x02]) + Data((key + ": " + value).utf8))
            })
    }
    func emit(_ packet: RuuviTag) { bluetooth.scans.last?(packet) }
    func cleanup() { presenter.viewWillDisappear(); sensorData.cleanup(); sensorData.measurements.cleanup() }
}

final class DiscoveryTransportSpy: DiscoveryBluetoothTransport {
    var state: BTScannerState = .poweredOn
    var scans = [(RuuviTag) -> Void]()
    var states = [(BTScannerState) -> Void]()
    var lost = [(RuuviTag) -> Void]()
    var cancellations = [String]()
    func scan(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        scans.append(receive)
        return { [weak self] in self?.cancellations.append("scan") }
    }
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void {
        states.append(receive)
        return { [weak self] in self?.cancellations.append("state") }
    }
    func observeLost(_ receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        lost.append(receive)
        return { [weak self] in self?.cancellations.append("lost") }
    }
    func setState(_ state: BTScannerState) { self.state = state; states.last?(state) }
}

final class DiscoveryViewSpy: UIViewController, DiscoverViewInput {
    struct Details {
        let sensor: NFCSensor?
        let message: String
        let add: Bool
        let go: Bool
        let upgrade: Bool
        let legacy: Bool
    }
    var ruuviTags = [DiscoverRuuviTagViewModel]()
    var isBluetoothEnabled = false
    var isCloseEnabled = false
    var bluetoothDialogs = [Bool]()
    var nfcStarts = 0
    var nfcStops = 0
    var details = [Details]()
    var upgradeDialogs = [String]()
    func showBluetoothDisabled(userDeclined: Bool) { bluetoothDialogs.append(userDeclined) }
    func startNFCSession() { nfcStarts += 1 }
    func stopNFCSession() { nfcStops += 1 }
    func showSensorDetailsDialog(
        for tag: NFCSensor?, message: String, showAddSensor: Bool,
        showGoToSensor: Bool, showUpgradeFirmware: Bool, isDF3: Bool
    ) {
        details.append(
            .init(
                sensor: tag, message: message, add: showAddSensor, go: showGoToSensor,
                upgrade: showUpgradeFirmware, legacy: isDF3))
    }
    func showUpdateFirmwareDialog(for uuid: String) { upgradeDialogs.append(uuid) }
}

final class DiscoveryOutputSpy: RuuviDiscoverOutput {
    var closes = 0
    var added = [AnyRuuviTagSensor]()
    var selected = [AnyRuuviTagSensor]()
    func ruuviDiscoverWantsClose(_ ruuviDiscover: RuuviDiscover) { closes += 1 }
    func ruuvi(discover: RuuviDiscover, didAdd ruuviTag: AnyRuuviTagSensor) { added.append(ruuviTag) }
    func ruuvi(discover: RuuviDiscover, didSelectFromNFC ruuviTag: RuuviTagSensor) { selected.append(ruuviTag.any) }
}
