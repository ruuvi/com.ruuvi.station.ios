import CoreBluetooth
import Foundation
import UIKit

protocol DfuCentralManaging: AnyObject {
    var state: CBManagerState { get }
    var isScanning: Bool { get }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?)
    func stopScan()
}

final class DfuCentralManagerAdapter: NSObject, DfuCentralManaging {
    private let manager: CBCentralManager

    init(delegate: CBCentralManagerDelegate, queue: DispatchQueue) {
        manager = CBCentralManager(delegate: delegate, queue: queue)
    }

    var state: CBManagerState {
        manager.state
    }

    var isScanning: Bool {
        manager.isScanning
    }

    func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]?) {
        manager.scanForPeripherals(withServices: serviceUUIDs, options: options)
    }

    func stopScan() {
        manager.stopScan()
    }
}

class DfuScanner: NSObject {
    private class LostObservation {
        var block: (DFUDevice) -> Void
        var lostDeviceDelay: TimeInterval

        init(block: @escaping ((DFUDevice) -> Void), lostDeviceDelay: TimeInterval) {
            self.block = block
            self.lostDeviceDelay = lostDeviceDelay
        }
    }

    let queue: DispatchQueue
    private let notificationCenter: NotificationCenter
    private let now: () -> Date
    private let managerFactory: (CBCentralManagerDelegate, DispatchQueue) -> DfuCentralManaging
    private lazy var manager: DfuCentralManaging = managerFactory(self, queue)

    private var lastSeen = [DFUDevice: Date]()
    private var lostTimer: DispatchSourceTimer?

    private var observations = (
        device: [UUID: (DFUDevice) -> Void](),
        lost: [UUID: LostObservation]()
    )

    private var includeScanServices: Bool = true {
        didSet {
            stopIfNeeded()
            startIfNeeded()
        }
    }

    private let scanServices = [
        CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123"),
        CBUUID(string: "FE59"),
        CBUUID(string: "180A"),
    ]

    deinit {
        stopLostDevicesTimer()
        notificationCenter.removeObserver(self)
    }

    override required init() {
        queue = DispatchQueue(label: "DfuScanner", qos: .userInteractive)
        notificationCenter = .default
        now = Date.init
        managerFactory = { delegate, queue in
            DfuCentralManagerAdapter(delegate: delegate, queue: queue)
        }
        super.init()
        observeApplicationState()
        queue.async { [weak self] in
            self?.startIfNeeded()
        }
    }

    init(
        queue: DispatchQueue = DispatchQueue(label: "DfuScanner", qos: .userInteractive),
        notificationCenter: NotificationCenter = .default,
        now: @escaping () -> Date = Date.init,
        managerFactory: @escaping (CBCentralManagerDelegate, DispatchQueue) -> DfuCentralManaging = {
            delegate,
            queue in
            DfuCentralManagerAdapter(delegate: delegate, queue: queue)
        }
    ) {
        self.queue = queue
        self.notificationCenter = notificationCenter
        self.now = now
        self.managerFactory = managerFactory
        super.init()
        observeApplicationState()
        queue.async { [weak self] in
            self?.startIfNeeded()
        }
    }

    private func observeApplicationState() {
        notificationCenter.addObserver(
            self,
            selector: #selector(willResignActiveNotification(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(didBecomeActiveNotification(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc func willResignActiveNotification(_: Notification) {
        queue.async { [weak self] in
            self?.manager.stopScan()
        }
    }

    @objc func didBecomeActiveNotification(_: Notification) {
        queue.async { [weak self] in
            self?.startIfNeeded()
        }
    }

    func startLostDevicesTimer() {
        lostTimer = DispatchSource.makeTimerSource(queue: queue)
        lostTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        lostTimer?.setEventHandler { [weak self] in
            self?.notifyLostDevices()
        }
        lostTimer?.activate()
    }

    func stopLostDevicesTimer() {
        lostTimer?.cancel()
        lostTimer = nil
    }

    func notifyLostDevices(currentDate: Date? = nil) {
        let referenceDate = currentDate ?? now()
        observations.lost.values.forEach { observation in
            var lostDevices = [DFUDevice]()
            for (device, seen) in lastSeen {
                let elapsed = referenceDate.timeIntervalSince(seen)
                if elapsed > observation.lostDeviceDelay {
                    lostDevices.append(device)
                }
            }
            for lostDevice in lostDevices {
                lastSeen.removeValue(forKey: lostDevice)
                observation.block(lostDevice)
            }
        }
    }

    func startIfNeeded() {
        if manager.state == .poweredOn, !manager.isScanning {
            manager.scanForPeripherals(
                withServices: self.includeScanServices ? scanServices : nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true)]
            )
        }
        let shouldObserveLostDevices = observations.lost.count > 0
        if shouldObserveLostDevices, !hasLostTimer {
            startLostDevicesTimer()
        }
    }

    func stopIfNeeded() {
        if manager.isScanning {
            manager.stopScan()
        }
        let shouldObserveLostDevices = observations.lost.count > 0
        if !shouldObserveLostDevices, hasLostTimer {
            stopLostDevicesTimer()
        }
    }

    func setIncludeScanServices(_ includeScanServices: Bool) {
        self.includeScanServices = includeScanServices
    }

    var hasLostTimer: Bool {
        lostTimer != nil
    }

    func processDiscoveredDevice(
        _ dfuDevice: DFUDevice,
        seenAt: Date? = nil
    ) {
        lastSeen[dfuDevice] = seenAt ?? now()
        observations.device.values.forEach { closure in
            closure(dfuDevice)
        }
    }

    @discardableResult
    func scan<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let id = UUID()
        queue.async { [weak self] in
            self?.observations.device[id] = { [weak self, weak observer] device in
                guard let observer
                else {
                    self?.observations.device.removeValue(forKey: id)
                    self?.stopIfNeeded()
                    return
                }

                closure(observer, device)
            }

            self?.startIfNeeded()
        }

        return RuuviDFUToken { [weak self] in
            self?.queue.async { [weak self] in
                self?.observations.device.removeValue(forKey: id)
                self?.stopIfNeeded()
            }
        }
    }

    @discardableResult
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let id = UUID()
        queue.async { [weak self] in
            self?.observations.lost[id] = LostObservation(block: { [weak self, weak observer] device in
                guard let observer
                else {
                    self?.observations.lost.removeValue(forKey: id)
                    self?.stopIfNeeded()
                    return
                }

                closure(observer, device)
            }, lostDeviceDelay: 5)

            self?.startIfNeeded()
        }

        return RuuviDFUToken { [weak self] in
            self?.queue.async { [weak self] in
                self?.observations.lost.removeValue(forKey: id)
                self?.stopIfNeeded()
            }
        }
    }
}

extension DfuScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_: CBCentralManager) {
        queue.async { [weak self] in
            self?.startIfNeeded()
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard RSSI.intValue != 127 else { return }
        let uuid = peripheral.identifier.uuidString
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let dfuDevice = DFUDevice(
            uuid: uuid,
            rssi: RSSI.intValue,
            isConnectable: isConnectable,
            name: name,
            peripheral: peripheral
        )
        processDiscoveredDevice(dfuDevice)
    }
}
