import CoreBluetooth
import Foundation
import RuuviDFU
import UIKit

class DfuScanner: NSObject {
    private class LostObservation {
        var block: (DFUDevice) -> Void
        var lostDeviceDelay: TimeInterval

        init(block: @escaping ((DFUDevice) -> Void), lostDeviceDelay: TimeInterval) {
            self.block = block
            self.lostDeviceDelay = lostDeviceDelay
        }
    }

    private let queue = DispatchQueue(label: "DfuScanner", qos: .userInteractive)
    private lazy var manager: CBCentralManager = .init(delegate: self, queue: queue)

    private var lastSeen = [DFUDevice: Date]()
    private var lostTimer: DispatchSourceTimer?

    private var observations = (
        device: [UUID: (DFUDevice) -> Void](),
        lost: [UUID: LostObservation]()
    )

    private let scanServices = [
        CBUUID(string: "00001530-1212-EFDE-1523-785FEABCD123"),
        CBUUID(string: "FE59"),
        CBUUID(string: "180A"),
    ]

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override required init() {
        super.init()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willResignActiveNotification(_:)),
                                               name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didBecomeActiveNotification(_:)),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        queue.async { [weak self] in
            self?.startIfNeeded()
        }
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

    private func notifyLostDevices() {
        observations.lost.values.forEach { observation in
            var lostDevices = [DFUDevice]()
            for (device, seen) in lastSeen {
                let elapsed = Date().timeIntervalSince(seen)
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

    private func startIfNeeded() {
        if manager.state == .poweredOn, !manager.isScanning {
            manager.scanForPeripherals(withServices: scanServices,
                                       options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true)])
        }
        let shouldObserveLostDevices = observations.lost.count > 0
        if shouldObserveLostDevices, lostTimer == nil {
            startLostDevicesTimer()
        }
    }

    private func stopIfNeeded() {
        if manager.isScanning {
            manager.stopScan()
        }
        let shouldObserveLostDevices = observations.lost.count > 0
        if !shouldObserveLostDevices, lostTimer != nil {
            stopLostDevicesTimer()
        }
    }

    @discardableResult
    func scan<T: AnyObject>(_ observer: T, closure: @escaping (T, DFUDevice) -> Void) -> RuuviDFUToken {
        let id = UUID()
        queue.async { [weak self] in
            self?.observations.device[id] = { [weak self, weak observer] device in
                guard let observer else {
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
                guard let observer else {
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

    func centralManager(_: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber)
    {
        guard RSSI.intValue != 127 else { return }
        let uuid = peripheral.identifier.uuidString
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue ?? false
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let dfuDevice = DFUDevice(uuid: uuid, rssi: RSSI.intValue, isConnectable: isConnectable, name: name)
        lastSeen[dfuDevice] = Date()
        observations.device.values.forEach { closure in
            closure(dfuDevice)
        }
    }
}
