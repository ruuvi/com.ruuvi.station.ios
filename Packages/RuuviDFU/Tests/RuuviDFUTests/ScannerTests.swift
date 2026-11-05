import CoreBluetooth
import Foundation
@testable import RuuviDFU
#if SWIFT_PACKAGE
    @testable import RuuviDFUImpl
#endif
import UIKit
import XCTest

final class ScannerTests: XCTestCase {
    func testScanStartsOnlyWithObserversAndKeepsRunningWhenOneCancels() {
        let fixture = ScannerFixture()
        let first = DeviceObserver()
        let second = DeviceObserver()
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 0)
        let one = fixture.scanner.scan(first) { $0.devices.append($1) }
        let two = fixture.scanner.scan(second) { $0.devices.append($1) }
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 1)
        XCTAssertEqual(
            fixture.backend.starts[0]?.map(\.uuidString),
            [
                "00001530-1212-EFDE-1523-785FEABCD123", "FE59", "180A",
            ])
        one.invalidate()
        fixture.flush()
        XCTAssertTrue(fixture.backend.isScanning)
        fixture.discover()
        XCTAssertTrue(first.devices.isEmpty)
        XCTAssertEqual(second.devices.count, 1)
        two.invalidate()
        fixture.flush()
        XCTAssertFalse(fixture.backend.isScanning)
        XCTAssertEqual(fixture.backend.stops, 1)
    }

    func testEveryLostObserverReceivesEachDisappearanceOnceAndRediscoveryStartsANewInterval() {
        let fixture = ScannerFixture()
        let first = DeviceObserver()
        let second = DeviceObserver()
        let one = fixture.scanner.lost(first) { $0.devices.append($1) }
        let two = fixture.scanner.lost(second) { $0.devices.append($1) }
        fixture.flush()
        fixture.discover()
        fixture.advance(to: 105)
        XCTAssertTrue(first.devices.isEmpty)
        fixture.advance(to: 105.001)
        XCTAssertEqual(first.devices.count, 1)
        XCTAssertEqual(second.devices.count, 1)
        fixture.advance(to: 110)
        XCTAssertEqual(first.devices.count, 1)
        fixture.discover()
        fixture.advance(to: 114)
        fixture.discover()
        fixture.advance(to: 118)
        XCTAssertEqual(first.devices.count, 1)
        fixture.advance(to: 120)
        XCTAssertEqual(first.devices.count, 2)
        XCTAssertEqual(second.devices.count, 2)
        one.invalidate()
        fixture.flush()
        XCTAssertTrue(fixture.backend.isScanning)
        two.invalidate()
        fixture.flush()
        XCTAssertFalse(fixture.backend.isScanning)
    }

    func testDiscoveryPreservesIdentityConnectabilityNameAndRSSIAndRejectsUnavailableRSSI() {
        let fixture = ScannerFixture()
        let observer = DeviceObserver()
        let token = fixture.scanner.scan(observer) { $0.devices.append($1) }
        fixture.flush()
        fixture.discover(rssi: 127)
        XCTAssertTrue(observer.devices.isEmpty)
        fixture.discover(
            rssi: -42,
            data: [
                CBAdvertisementDataLocalNameKey: "RuuviBoot", CBAdvertisementDataIsConnectable: NSNumber(value: true),
            ])
        fixture.discover(rssi: -60)
        XCTAssertEqual(observer.devices.count, 2)
        let device = observer.devices[0]
        XCTAssertEqual(device.uuid, fixture.peripheral.identifier.uuidString)
        XCTAssertTrue(device.peripheral === fixture.peripheral)
        XCTAssertEqual(device.name, "RuuviBoot")
        XCTAssertEqual(device.rssi, -42)
        XCTAssertTrue(device.isConnectable)
        XCTAssertNil(observer.devices[1].name)
        XCTAssertFalse(observer.devices[1].isConnectable)
        XCTAssertEqual(Set(observer.devices).count, 1, "Signal changes do not change device identity")
        token.invalidate()
    }

    func testServiceFilterRestartsOnlyWhenChangedAndBluetoothPowerControlsScanning() {
        let fixture = ScannerFixture()
        let observer = DeviceObserver()
        fixture.queue.sync { fixture.backend.state = .poweredOff }
        let token = fixture.scanner.scan(observer) { $0.devices.append($1) }
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 0)
        fixture.queue.sync {
            fixture.backend.state = .poweredOn
            fixture.backend.onStateChange?()
        }
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 1)
        fixture.scanner.setIncludeScanServices(true)
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 1)
        fixture.scanner.setIncludeScanServices(false)
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 2)
        XCTAssertNil(fixture.backend.starts.last!)
        fixture.scanner.setIncludeScanServices(true)
        fixture.flush()
        XCTAssertEqual(fixture.backend.starts.count, 3)
        fixture.queue.sync {
            fixture.backend.state = .poweredOff
            fixture.backend.onStateChange?()
        }
        fixture.flush()
        XCTAssertFalse(fixture.backend.isScanning)
        token.invalidate()
    }

    func testBackgroundStopsScanningAndDeliveryUntilForeground() {
        let fixture = ScannerFixture()
        let observer = DeviceObserver()
        let scan = fixture.scanner.scan(observer) { $0.devices.append($1) }
        let lost = fixture.scanner.lost(observer) { $0.lost.append($1) }
        fixture.flush()
        fixture.discover()
        fixture.center.post(name: UIApplication.willResignActiveNotification, object: nil)
        fixture.flush()
        XCTAssertFalse(fixture.backend.isScanning)
        fixture.discover()
        fixture.advance(to: 110)
        XCTAssertEqual(observer.devices.count, 1)
        XCTAssertTrue(observer.lost.isEmpty)
        fixture.center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        fixture.flush()
        XCTAssertTrue(fixture.backend.isScanning)
        fixture.advance(to: 111)
        XCTAssertEqual(observer.lost.count, 1)
        scan.invalidate()
        lost.invalidate()
    }

    func testDeadObserversAreReleasedAndRemovedWithoutInterruptingLiveObservers() {
        let fixture = ScannerFixture()
        var observer: DeviceObserver? = DeviceObserver()
        weak var weakObserver = observer
        let scan = fixture.scanner.scan(observer!) { $0.devices.append($1) }
        let lost = fixture.scanner.lost(observer!) { $0.lost.append($1) }
        fixture.flush()
        observer = nil
        XCTAssertNil(weakObserver)
        fixture.discover()
        fixture.advance(to: 110)
        XCTAssertFalse(fixture.backend.isScanning)
        scan.invalidate()
        lost.invalidate()
        fixture.flush()
    }

    func testTimerAndScannerAreReleasedWhenLastObserverCancels() async throws {
        let queue = DispatchQueue(label: "scanner-timer-test")
        let backend = ScanningSpy()
        let observer = DeviceObserver()
        var scanner: DfuScanner? = DfuScanner(
            manager: backend, queue: queue, now: { Date(timeIntervalSince1970: 100) },
            notificationCenter: NotificationCenter())
        weak var weakScanner = scanner
        let token = scanner!.lost(observer) { $0.devices.append($1) }
        queue.sync {}
        XCTAssertTrue(backend.isScanning)
        token.invalidate()
        queue.sync {}
        XCTAssertFalse(backend.isScanning)
        scanner = nil
        queue.sync {}
        XCTAssertNil(weakScanner)
    }

    func testCancellationTokenRunsOnlyOnceEvenWithConcurrentInvalidationsAndReentry() {
        let counter = LockedCounter()
        let token = RuuviDFUToken { counter.increment() }
        DispatchQueue.concurrentPerform(iterations: 100) { _ in token.invalidate() }
        XCTAssertEqual(counter.value, 1)
        var recursive: RuuviDFUToken?
        recursive = RuuviDFUToken { recursive?.invalidate() }
        recursive?.invalidate()
        recursive = nil
    }
}

final class TestDFUPeripheral: DFUPeripheral {
    let identifier = UUID()
}

private final class ScannerFixture {
    let queue = DispatchQueue(label: "scanner-tests")
    let backend = ScanningSpy()
    let center = NotificationCenter()
    let peripheral = TestDFUPeripheral()
    private let clock = ScannerClock()
    let scanner: DfuScanner
    init() {
        let clock = clock
        scanner = DfuScanner(
            manager: backend, queue: queue, now: { clock.date },
            automaticallyCheckLostDevices: false, notificationCenter: center)
    }
    func flush() { queue.sync {} }
    func discover(rssi: Int = -50, data: [String: Any] = [:]) {
        queue.sync { backend.onDiscovery?(peripheral, data, rssi) }
        flush()
    }
    func advance(to time: TimeInterval) {
        queue.sync {
            clock.date = Date(timeIntervalSince1970: time)
            scanner.notifyLostDevices()
        }
    }
}

private final class ScannerClock { var date = Date(timeIntervalSince1970: 100) }
private final class DeviceObserver {
    var devices: [DFUDevice] = []
    var lost: [DFUDevice] = []
}
private final class ScanningSpy: DFUScanning {
    var state: CBManagerState = .poweredOn
    var isScanning = false
    var onStateChange: (() -> Void)?
    var onDiscovery: ((DFUPeripheral, [String: Any], Int) -> Void)?
    var starts: [[CBUUID]?] = []
    var stops = 0
    func scan(services: [CBUUID]?) { starts.append(services); isScanning = true }
    func stop() { stops += 1; isScanning = false }
}
private final class LockedCounter {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); defer { lock.unlock() }; count += 1 }
}
