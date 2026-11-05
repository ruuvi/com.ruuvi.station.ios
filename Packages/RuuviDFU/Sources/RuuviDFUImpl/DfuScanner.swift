#if SWIFT_PACKAGE
    import RuuviDFU
#endif
import CoreBluetooth
import Foundation
import UIKit

protocol DFUScanning: AnyObject {
    var state: CBManagerState { get }
    var isScanning: Bool { get }
    var onStateChange: (() -> Void)? { get set }
    var onDiscovery: ((DFUPeripheral, [String: Any], Int) -> Void)? { get set }
    func scan(services: [CBUUID]?)
    func stop()
}

final class DFUBluetoothScanner: NSObject, DFUScanning, CBCentralManagerDelegate {
    private let queue: DispatchQueue
    private lazy var manager = CBCentralManager(delegate: self, queue: queue)
    var onStateChange: (() -> Void)?
    var onDiscovery: ((DFUPeripheral, [String: Any], Int) -> Void)?
    var state: CBManagerState { manager.state }
    var isScanning: Bool { manager.isScanning }

    init(queue: DispatchQueue) {
        self.queue = queue
        super.init()
    }
    func scan(services: [CBUUID]?) {
        manager.scanForPeripherals(
            withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    func stop() { manager.stopScan() }
    func centralManagerDidUpdateState(_: CBCentralManager) { onStateChange?() }
    func centralManager(
        _: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi: NSNumber
    ) {
        onDiscovery?(peripheral, advertisementData, rssi.intValue)
    }
}

final class DfuScanner {
    private let queue: DispatchQueue
    private let manager: DFUScanning
    private let now: () -> Date
    private let automaticallyCheckLostDevices: Bool
    private let notificationCenter: NotificationCenter
    private var lifecycleTokens: [NSObjectProtocol] = []
    private var lastSeen: [DFUDevice: Date] = [:]
    private var deviceObservations: [UUID: (DFUDevice) -> Void] = [:]
    private var lostObservations: [UUID: (DFUDevice) -> Void] = [:]
    private var lostTimer: DispatchSourceTimer?
    private var includeScanServices = true
    private var active = true
    private let scanServices = [
        CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123"),
        CBUUID(string: "FE59"), CBUUID(string: "180A"),
    ]

    init(
        manager: DFUScanning? = nil,
        queue: DispatchQueue = DispatchQueue(label: "DfuScanner", qos: .userInteractive),
        now: @escaping () -> Date = Date.init,
        automaticallyCheckLostDevices: Bool = true,
        notificationCenter: NotificationCenter = .default
    ) {
        self.queue = queue
        self.manager = manager ?? DFUBluetoothScanner(queue: queue)
        self.now = now
        self.automaticallyCheckLostDevices = automaticallyCheckLostDevices
        self.notificationCenter = notificationCenter
        self.manager.onStateChange = { [weak self] in
            self?.queue.async { [weak self] in self?.updateScanning() }
        }
        self.manager.onDiscovery = { [weak self] peripheral, data, rssi in
            self?.queue.async { [weak self] in self?.discovered(peripheral, data: data, rssi: rssi) }
        }
        lifecycleTokens = [
            notificationCenter.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: nil
            ) { [weak self] _ in self?.setActive(false) },
            notificationCenter.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
            ) { [weak self] _ in self?.setActive(true) },
        ]
    }

    deinit {
        lifecycleTokens.forEach(notificationCenter.removeObserver)
        lostTimer?.cancel()
        let manager = manager
        queue.async { manager.stop() }
    }

    private func setActive(_ value: Bool) {
        queue.async { [weak self] in
            self?.active = value
            self?.updateScanning()
        }
    }

    func setIncludeScanServices(_ value: Bool) {
        queue.async { [weak self] in
            guard let self, self.includeScanServices != value else { return }
            self.includeScanServices = value
            if self.manager.isScanning { self.manager.stop() }
            self.updateScanning()
        }
    }

    private func updateScanning() {
        let hasObservers = !deviceObservations.isEmpty || !lostObservations.isEmpty
        if active && hasObservers && manager.state == .poweredOn {
            if !manager.isScanning { manager.scan(services: includeScanServices ? scanServices : nil) }
        } else if manager.isScanning {
            manager.stop()
        }
        let needsTimer = active && !lostObservations.isEmpty && automaticallyCheckLostDevices
        if needsTimer && lostTimer == nil {
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + 1, repeating: .seconds(1))
            timer.setEventHandler { [weak self] in self?.notifyLostDevices() }
            lostTimer = timer
            timer.activate()
        } else if !needsTimer {
            lostTimer?.cancel()
            lostTimer = nil
        }
        if !hasObservers { lastSeen.removeAll() }
    }

    @discardableResult
    func scan<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let id = UUID()
        queue.async { [weak self, weak observer] in
            guard let self, let observer else { return }
            self.deviceObservations[id] = { [weak self, weak observer] device in
                guard let observer else {
                    self?.deviceObservations.removeValue(forKey: id)
                    self?.updateScanning()
                    return
                }
                closure(observer, device)
            }
            self.updateScanning()
        }
        return RuuviDFUToken { [weak self] in
            self?.queue.async { [weak self] in
                self?.deviceObservations.removeValue(forKey: id)
                self?.updateScanning()
            }
        }
    }

    @discardableResult
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let id = UUID()
        queue.async { [weak self, weak observer] in
            guard let self, let observer else { return }
            self.lostObservations[id] = { [weak self, weak observer] device in
                guard let observer else {
                    self?.lostObservations.removeValue(forKey: id)
                    self?.updateScanning()
                    return
                }
                closure(observer, device)
            }
            self.updateScanning()
        }
        return RuuviDFUToken { [weak self] in
            self?.queue.async { [weak self] in
                self?.lostObservations.removeValue(forKey: id)
                self?.updateScanning()
            }
        }
    }

    /// Called on the scanner queue by the timer or a deterministic scheduler.
    func notifyLostDevices() {
        guard active else { return }
        let deadline = now().addingTimeInterval(-5)
        let expired = lastSeen.filter { $0.value < deadline }.map(\.key)
        for device in expired {
            lastSeen.removeValue(forKey: device)
            for callback in Array(lostObservations.values) { callback(device) }
        }
    }

    private func discovered(_ peripheral: DFUPeripheral, data: [String: Any], rssi: Int) {
        guard active, rssi != 127 else { return }
        let device = DFUDevice(
            uuid: peripheral.identifier.uuidString, rssi: rssi,
            isConnectable: (data[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false,
            name: data[CBAdvertisementDataLocalNameKey] as? String, peripheral: peripheral)
        if !lostObservations.isEmpty { lastSeen[device] = now() }
        for callback in Array(deviceObservations.values) { callback(device) }
    }
}
