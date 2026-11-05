import Combine
import CoreBluetooth
import Foundation
@testable import RuuviDFU
#if SWIFT_PACKAGE
    @testable import RuuviDFUImpl
#endif
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif
import XCTest

final class DFUAPITests: XCTestCase {
    func testFacadeForwardsDiscoveryFilterAndLostDeviceEvents() {
        let queue = DispatchQueue(label: "dfu-api-tests")
        let backend = APIScanBackend()
        var time = Date(timeIntervalSince1970: 100)
        let scanner = DfuScanner(
            manager: backend, queue: queue, now: { time },
            automaticallyCheckLostDevices: false, notificationCenter: NotificationCenter())
        let service = RuuviDFUImpl(scanner: scanner)
        let observer = APIObserver()
        let scan = service.scan(observer, includeScanServices: false) { $0.discovered.append($1) }
        let lost = service.lost(observer) { $0.lost.append($1) }
        queue.sync {}
        XCTAssertTrue(backend.isScanning)
        XCTAssertNil(backend.services)
        let peripheral = TestDFUPeripheral()
        queue.sync { backend.onDiscovery?(peripheral, [:], -45) }
        queue.sync {}
        XCTAssertEqual(observer.discovered.first?.uuid, peripheral.identifier.uuidString)
        queue.sync {
            time = Date(timeIntervalSince1970: 106)
            scanner.notifyLostDevices()
        }
        XCTAssertEqual(observer.lost, observer.discovered)
        scan.invalidate()
        lost.invalidate()
        queue.sync {}
        XCTAssertFalse(backend.isScanning)
    }

    func testFacadeReportsInvalidFirmwareInputsThroughEachPublicOverload() async throws {
        let service = RuuviDFUImpl()
        let peripheral = TestDFUPeripheral()
        let device = DFUDevice(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true,
            name: nil, peripheral: peripheral)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        XCTAssertNil(service.firmwareFromUrl(url: missing))
        let firmware = DFUFirmware(binFile: Data([1]), datFile: nil, type: .application)
        let publishers = [
            service.flashFirmware(uuid: "invalid", with: firmware),
            service.flashFirmware(dfuDevice: device, with: missing),
            service.flashFirmware(dfuDevice: device, with: [URL]()),
        ]
        for publisher in publishers {
            let failure = expectation(description: "Invalid firmware rejected")
            let token = publisher.sink(
                receiveCompletion: {
                    if case .failure = $0 { failure.fulfill() }
                }, receiveValue: { _ in XCTFail("Invalid inputs must not flash a device") })
            await fulfillment(of: [failure], timeout: 2)
            withExtendedLifetime(token) {}
        }
        XCTAssertFalse(service.stopFlashFirmware(device: device))
    }

    func testSingleFileCompatibilityDefaultRejectsEmptyBatchAndForwardsTheFirstFile() {
        let service = SingleFileDFU()
        let peripheral = TestDFUPeripheral()
        let device = DFUDevice(
            uuid: peripheral.identifier.uuidString, rssi: -50, isConnectable: true,
            name: nil, peripheral: peripheral)
        var failures = 0
        var completed = 0
        let empty = service.flashFirmware(dfuDevice: device, with: [URL]()).sink(
            receiveCompletion: { if case .failure = $0 { failures += 1 } }, receiveValue: { _ in })
        let first = URL(fileURLWithPath: "/app.bin")
        let batch = service.flashFirmware(dfuDevice: device, with: [first, URL(fileURLWithPath: "/extra.bin")]).sink(
            receiveCompletion: { if case .finished = $0 { completed += 1 } }, receiveValue: { _ in })
        XCTAssertEqual(failures, 1)
        XCTAssertEqual(completed, 1)
        XCTAssertEqual(service.urls, [first])
        withExtendedLifetime((empty, batch)) {}
    }
}

private final class APIScanBackend: DFUScanning {
    var state: CBManagerState = .poweredOn
    var isScanning = false
    var onStateChange: (() -> Void)?
    var onDiscovery: ((DFUPeripheral, [String: Any], Int) -> Void)?
    var services: [CBUUID]?
    func scan(services: [CBUUID]?) { self.services = services; isScanning = true }
    func stop() { isScanning = false }
}
private final class APIObserver {
    var discovered: [DFUDevice] = []
    var lost: [DFUDevice] = []
}
private final class SingleFileDFU: RuuviDFU {
    var urls: [URL] = []
    func scan<T: AnyObject>(
        _ observer: T, includeScanServices: Bool, closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken { .init(cancellationClosure: {}) }
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        .init(cancellationClosure: {})
    }
    func firmwareFromUrl(url: URL) -> DFUFirmware? { nil }
    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        Empty().eraseToAnyPublisher()
    }
    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        urls.append(firmwareURL)
        return Just(.done).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    func stopFlashFirmware(device: DFUDevice) -> Bool { false }
}
