import BTKit
import Combine
import Foundation
import NordicDFU
import RuuviDaemon
import RuuviDFU
import XCTest
@testable import RuuviFirmware

@MainActor final class ModuleFirmwareFixture {
    let radio = ModuleFirmwareRadio()
    let daemon = ModuleFirmwareDaemon()
    var battery = [(String, (RuuviTag) -> Void)]()
    var revision = [(String, (Result<String, Error>) -> Void)]()
    var batteryCancellations = 0
    func interactor(timeout: TimeInterval = 1, session: URLSession = .shared) -> FirmwareInteractor {
        FirmwareInteractor(
            background: BTKit.background, foreground: BTKit.foreground, propertiesDaemon: daemon,
            ruuviDFU: radio, firmwareRepository: FirmwareRepositoryImpl(), session: session,
            observeBattery: { [weak self] uuid, receive in
                self?.battery.append((uuid, receive))
                return { [weak self] in self?.batteryCancellations += 1 }
            },
            firmwareRevision: { [weak self] uuid, receive in self?.revision.append((uuid, receive)) },
            revisionTimeout: timeout)
    }
    func packet(temperature: Double?, voltage: Double?) -> RuuviTag {
        .v5(
            .init(
                uuid: UUID().uuidString, rssi: -50, isConnectable: true, version: 5,
                humidity: 50, temperature: temperature, pressure: 1000, accelerationX: 0, accelerationY: 0,
                accelerationZ: 1, voltage: voltage, movementCounter: 1, measurementSequenceNumber: 1, txPower: 4,
                mac: "AA:BB:CC:DD:EE:FF"))
    }
    func device(uuid: String) -> DFUDevice {
        .init(uuid: uuid, rssi: -50, isConnectable: true, name: "Firmware", peripheral: ModuleFirmwarePeripheral())
    }
}

final class ModuleFirmwareDaemon: RuuviTagPropertiesDaemon {
    var starts = 0
    func start() { starts += 1 }
    func stop() {}
}
private final class ModuleFirmwarePeripheral: DFUPeripheral { let identifier = UUID() }

final class ModuleFirmwareRadio: RuuviDFU {
    var scans = [(DFUDevice) -> Void]()
    var lost = [(DFUDevice) -> Void]()
    var scanStops = 0
    var lostStops = 0
    var files = [URL]()
    var flashed = [String]()
    var validArchive = true
    func scan<T: AnyObject>(_ observer: T, includeScanServices: Bool, closure: @escaping (T, DFUDevice) -> Void)
        -> RuuviDFUToken
    {
        XCTAssertFalse(includeScanServices)
        scans.append { [weak observer] device in if let observer { closure(observer, device) } }
        return .init { [weak self] in self?.scanStops += 1 }
    }
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        lost.append { [weak observer] device in if let observer { closure(observer, device) } }
        return .init { [weak self] in self?.lostStops += 1 }
    }
    func firmwareFromUrl(url: URL) -> DFUFirmware? {
        files.append(url)
        return validArchive ? DFUFirmware(binFile: Data([1]), datFile: nil, type: .application) : nil
    }
    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        flashed.append(uuid)
        return Just(.done).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func stopFlashFirmware(device: DFUDevice) -> Bool { false }
}

@MainActor func waitForFirmwareState(_ message: String, _ ready: () -> Bool) async {
    for _ in 0..<200 {
        if ready() { return }
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
    XCTFail(message)
}

@MainActor func drainFirmwareCallbacks() async {
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
}
