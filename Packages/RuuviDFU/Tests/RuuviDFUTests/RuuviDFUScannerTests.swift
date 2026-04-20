@testable import RuuviDFU
import CoreBluetooth
import Foundation
import UIKit
import XCTest

final class RuuviDFUScannerTests: XCTestCase {
    func testBaseScannerStartAndStopLostDevicesTimerManageTimerState() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = DfuScanner(
            queue: DispatchQueue(label: "RuuviDFUScannerTests.base-timer"),
            notificationCenter: NotificationCenter(),
            managerFactory: { _, _ in manager }
        )
        scanner.waitForQueue()

        scanner.startLostDevicesTimer()
        XCTAssertTrue(scanner.hasLostTimer)

        scanner.stopLostDevicesTimer()
        XCTAssertFalse(scanner.hasLostTimer)
    }

    func testCentralManagerAdapterForwardsCoreBluetoothCalls() {
        let adapter = DfuCentralManagerAdapter(
            delegate: CentralDelegateSpy(),
            queue: DispatchQueue(label: "RuuviDFUScannerTests.adapter")
        )

        _ = adapter.state
        _ = adapter.isScanning
        adapter.scanForPeripherals(withServices: nil, options: nil)
        adapter.stopScan()

        XCTAssertNotNil(adapter)
    }

    func testInjectedScannerDefaultManagerFactoryCreatesAdapter() {
        let scanner = DfuScanner(
            queue: DispatchQueue(label: "RuuviDFUScannerTests.default-manager-factory"),
            notificationCenter: NotificationCenter()
        )

        scanner.waitForQueue()

        XCTAssertNotNil(scanner)
    }

    func testLostDevicesTimerEventNotifiesExpiredDevices() {
        let manager = CentralManagerSpy(state: .poweredOff)
        var currentDate = Date(timeIntervalSince1970: 0)
        let scanner = DfuScanner(
            queue: DispatchQueue(label: "RuuviDFUScannerTests.timer-event"),
            notificationCenter: NotificationCenter(),
            now: { currentDate },
            managerFactory: { _, _ in manager }
        )
        let observer = DummyObserver()
        let lostExpectation = expectation(description: "lost device emitted by timer")

        scanner.processDiscoveredDevice(
            makeScannerDevice(uuid: "timer-lost-device"),
            seenAt: Date(timeIntervalSince1970: 0)
        )
        currentDate = Date(timeIntervalSince1970: 10)

        _ = scanner.lost(observer) { _, device in
            if device.uuid == "timer-lost-device" {
                lostExpectation.fulfill()
            }
        }
        scanner.waitForQueue()

        wait(for: [lostExpectation], timeout: 2)
        scanner.stopLostDevicesTimer()
    }

    func testScannerStartsBluetoothScanWithDefaultServices() {
        let manager = CentralManagerSpy(state: .poweredOn)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        manager.reset()

        _ = scanner.scan(DummyObserver()) { _, _ in }
        scanner.waitForQueue()

        XCTAssertEqual(manager.scanRequests.count, 1)
        XCTAssertEqual(manager.scanRequests.first??.count, 3)
        let options = manager.scanOptions.first as? [String: NSNumber]
        XCTAssertEqual(options?[CBCentralManagerScanOptionAllowDuplicatesKey]?.boolValue, true)
    }

    func testScannerCanRestartWithoutServiceFilter() {
        let manager = CentralManagerSpy(state: .poweredOn)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        let baselineStopCount = manager.stopScanCount
        let baselineScanCount = manager.scanRequests.count

        scanner.setIncludeScanServices(false)

        XCTAssertEqual(manager.stopScanCount, baselineStopCount + 1)
        XCTAssertEqual(manager.scanRequests.count, baselineScanCount + 1)
        XCTAssertNil(manager.scanRequests.last!)
    }

    func testLostObserverStartsAndStopsTimer() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()

        let token = scanner.lost(DummyObserver()) { _, _ in }
        scanner.waitForQueue()
        XCTAssertTrue(scanner.hasLostTimer)

        token.invalidate()
        scanner.waitForQueue()
        XCTAssertFalse(scanner.hasLostTimer)
    }

    func testScannerNotifiesObserversAndExpiresLostDevices() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        let observer = DummyObserver()
        var seenDevices: [DFUDevice] = []
        var lostDevices: [DFUDevice] = []

        _ = scanner.scan(observer) { _, device in
            seenDevices.append(device)
        }
        _ = scanner.lost(observer) { _, device in
            lostDevices.append(device)
        }
        scanner.waitForQueue()

        let device = makeScannerDevice(uuid: "scanner-device")
        scanner.processDiscoveredDevice(
            device,
            seenAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(seenDevices.map(\.uuid), ["scanner-device"])

        scanner.notifyLostDevices(currentDate: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(lostDevices.map(\.uuid), ["scanner-device"])

        scanner.notifyLostDevices(currentDate: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(lostDevices.map(\.uuid), ["scanner-device"])
    }

    func testScanObservationRemovesReleasedObserverAndStopsScanning() {
        let manager = CentralManagerSpy(state: .poweredOn)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        var observer: DummyObserver? = DummyObserver()

        _ = scanner.scan(observer!) { _, _ in
            XCTFail("Released observer should not receive devices")
        }
        scanner.waitForQueue()
        observer = nil

        scanner.processDiscoveredDevice(makeScannerDevice())

        XCTAssertEqual(manager.stopScanCount, 1)
    }

    func testScanTokenInvalidationRemovesObservationAndStopsScanning() {
        let manager = CentralManagerSpy(state: .poweredOn)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        manager.reset()

        let token = scanner.scan(DummyObserver()) { _, _ in
            XCTFail("Invalidated observer should not receive devices")
        }
        scanner.waitForQueue()
        XCTAssertEqual(manager.scanRequests.count, 1)

        token.invalidate()
        scanner.waitForQueue()
        scanner.processDiscoveredDevice(makeScannerDevice(uuid: "invalidated-scan-device"))

        XCTAssertEqual(manager.stopScanCount, 1)
    }

    func testLostObservationRemovesReleasedObserverAndStopsLostTimer() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        var observer: DummyObserver? = DummyObserver()

        _ = scanner.lost(observer!) { _, _ in
            XCTFail("Released observer should not receive lost devices")
        }
        scanner.waitForQueue()
        observer = nil

        scanner.processDiscoveredDevice(
            makeScannerDevice(uuid: "lost-observer-device"),
            seenAt: Date(timeIntervalSince1970: 0)
        )
        scanner.notifyLostDevices(currentDate: Date(timeIntervalSince1970: 10))

        XCTAssertFalse(scanner.hasLostTimer)
    }

    func testNotifyLostDevicesUsesInjectedNowWhenReferenceDateIsOmitted() {
        let manager = CentralManagerSpy(state: .poweredOff)
        var currentDate = Date(timeIntervalSince1970: 0)
        let scanner = RecordingScanner(
            manager: manager,
            now: { currentDate }
        )
        scanner.waitForQueue()
        let observer = DummyObserver()
        var lostDevices: [DFUDevice] = []

        _ = scanner.lost(observer) { _, device in
            lostDevices.append(device)
        }
        scanner.waitForQueue()
        scanner.processDiscoveredDevice(
            makeScannerDevice(uuid: "injected-now-device"),
            seenAt: Date(timeIntervalSince1970: 0)
        )

        currentDate = Date(timeIntervalSince1970: 10)
        scanner.notifyLostDevices()

        XCTAssertEqual(lostDevices.map(\.uuid), ["injected-now-device"])
    }

    func testWillResignActiveStopsScanAndBecomeActiveRestartsIt() {
        let manager = CentralManagerSpy(state: .poweredOn)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        manager.reset()

        scanner.willResignActiveNotification(Notification(name: UIApplication.willResignActiveNotification))
        scanner.waitForQueue()
        XCTAssertEqual(manager.stopScanCount, 1)

        scanner.didBecomeActiveNotification(Notification(name: UIApplication.didBecomeActiveNotification))
        scanner.waitForQueue()
        XCTAssertEqual(manager.scanRequests.count, 1)
    }

    func testCentralManagerStateUpdateStartsScanningWhenPoweredOn() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        manager.reset()
        manager.state = .poweredOn

        scanner.centralManagerDidUpdateState(fakeCentralManager())
        scanner.waitForQueue()

        XCTAssertEqual(manager.scanRequests.count, 1)
    }

    func testDiscoveryIgnoresInvalidRSSIAndPublishesValidAdvertisement() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        let observer = DummyObserver()
        var seenDevices: [DFUDevice] = []

        _ = scanner.scan(observer) { _, device in
            seenDevices.append(device)
        }
        scanner.waitForQueue()

        scanner.centralManager(
            fakeCentralManager(),
            didDiscover: fakePeripheral(),
            advertisementData: [
                CBAdvertisementDataIsConnectable: NSNumber(value: true),
                CBAdvertisementDataLocalNameKey: "Ruuvi Bootloader",
            ],
            rssi: 127
        )
        XCTAssertTrue(seenDevices.isEmpty)

        scanner.centralManager(
            fakeCentralManager(),
            didDiscover: fakePeripheral(),
            advertisementData: [
                CBAdvertisementDataIsConnectable: NSNumber(value: true),
                CBAdvertisementDataLocalNameKey: "Ruuvi Bootloader",
            ],
            rssi: -55
        )

        XCTAssertEqual(seenDevices.count, 1)
        XCTAssertEqual(seenDevices.first?.rssi, -55)
        XCTAssertEqual(seenDevices.first?.isConnectable, true)
        XCTAssertEqual(seenDevices.first?.name, "Ruuvi Bootloader")
    }

    func testDiscoveryDefaultsMissingAdvertisementFields() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = RecordingScanner(manager: manager)
        scanner.waitForQueue()
        let observer = DummyObserver()
        var seenDevices: [DFUDevice] = []

        _ = scanner.scan(observer) { _, device in
            seenDevices.append(device)
        }
        scanner.waitForQueue()

        scanner.centralManager(
            fakeCentralManager(),
            didDiscover: fakePeripheral(),
            advertisementData: [:],
            rssi: -63
        )

        XCTAssertEqual(seenDevices.count, 1)
        XCTAssertEqual(seenDevices.first?.rssi, -63)
        XCTAssertEqual(seenDevices.first?.isConnectable, false)
        XCTAssertNil(seenDevices.first?.name)
    }

    func testDefaultScannerUsesDefaultNowProviderForLostDeviceCheck() {
        let scanner = DfuScanner()
        scanner.waitForQueue()

        scanner.notifyLostDevices()

        XCTAssertNotNil(scanner)
    }

    func testInjectedScannerDefaultNowProviderIsUsedForLostDeviceCheck() {
        let manager = CentralManagerSpy(state: .poweredOff)
        let scanner = DfuScanner(
            queue: DispatchQueue(label: "RuuviDFUScannerTests.default-now-provider"),
            notificationCenter: NotificationCenter(),
            managerFactory: { _, _ in manager }
        )
        scanner.waitForQueue()

        scanner.notifyLostDevices()

        XCTAssertNotNil(scanner)
    }
}

private func makeScannerDevice(uuid: String = UUID().uuidString) -> DFUDevice {
    DFUDevice(
        uuid: uuid,
        rssi: -60,
        isConnectable: true,
        name: "Ruuvi",
        peripheral: fakePeripheral()
    )
}

private func fakePeripheral() -> CBPeripheral {
    unsafeBitCast(FakePeripheral(), to: CBPeripheral.self)
}

private func fakeCentralManager() -> CBCentralManager {
    unsafeBitCast(FakeCentralManager(), to: CBCentralManager.self)
}

private final class RecordingScanner: DfuScanner {
    var startedLostTimerCount = 0
    var stoppedLostTimerCount = 0
    private var simulatedLostTimerIsActive = false

    required init() {
        fatalError("Use init(manager:queue:)")
    }

    init(
        manager: CentralManagerSpy,
        queue: DispatchQueue = DispatchQueue(label: "RuuviDFUScannerTests"),
        now: @escaping () -> Date = Date.init
    ) {
        super.init(
            queue: queue,
            notificationCenter: NotificationCenter(),
            now: now,
            managerFactory: { _, _ in manager }
        )
    }

    override func startLostDevicesTimer() {
        startedLostTimerCount += 1
        simulatedLostTimerIsActive = true
    }

    override func stopLostDevicesTimer() {
        stoppedLostTimerCount += 1
        simulatedLostTimerIsActive = false
    }

    override var hasLostTimer: Bool {
        simulatedLostTimerIsActive
    }

}

private extension DfuScanner {
    func waitForQueue() {
        queue.sync {}
    }
}

private final class CentralManagerSpy: DfuCentralManaging {
    var state: CBManagerState
    var isScanning = false
    var scanRequests: [[CBUUID]?] = []
    var scanOptions: [[String: Any]?] = []
    var stopScanCount = 0

    init(state: CBManagerState) {
        self.state = state
    }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        isScanning = true
        scanRequests.append(serviceUUIDs)
        scanOptions.append(options)
    }

    func stopScan() {
        isScanning = false
        stopScanCount += 1
    }

    func reset() {
        isScanning = false
        scanRequests.removeAll()
        scanOptions.removeAll()
        stopScanCount = 0
    }
}

private final class CentralDelegateSpy: NSObject, CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_: CBCentralManager) {}
}

private final class FakeCentralManager: NSObject {}
private final class FakePeripheral: NSObject {
    @objc let identifier = UUID()
}
private final class DummyObserver: NSObject {}
