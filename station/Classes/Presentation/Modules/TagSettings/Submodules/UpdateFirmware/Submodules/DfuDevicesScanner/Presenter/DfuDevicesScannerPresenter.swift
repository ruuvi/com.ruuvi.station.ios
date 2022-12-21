import Foundation
import BTKit
import UIKit
import RuuviOntology
import RuuviDFU
import CoreBluetooth

class DfuDevicesScannerPresenter: NSObject, DfuDevicesScannerModuleInput {
    weak var view: DfuDevicesScannerViewInput!
    var router: DfuDevicesScannerRouter!

    var foreground: BTForeground!
    var ruuviDfu: RuuviDFU!

    private var bluetoothStateToken: ObservationToken?
    private var ruuviDfuScanToken: RuuviDFUToken?
    private var ruuviDfuLostToken: RuuviDFUToken?

    private var ruuviTag: RuuviTagSensor!
    private var dfuDevices = Set<DFUDevice>() {
        didSet {
            syncViewModels()
        }
    }

    private var isBluetoothPermissionGranted: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        // Before iOS 13, Bluetooth permissions are not required
        return true
    }

    func configure(ruuviTag: RuuviTagSensor) {
        self.ruuviTag = ruuviTag
    }

    func syncViewModels() {
        var viewModels: [DfuDeviceViewModel] = []
        dfuDevices.forEach { device in
            let image: UIImage?
            if device.rssi < -80 {
                image = UIImage(named: "icon-connection-1")
            } else if device.rssi < -50 {
                image = UIImage(named: "icon-connection-2")
            } else {
                image = UIImage(named: "icon-connection-3")
            }
            viewModels.append(DfuDeviceViewModel(id: device.uuid,
                                                 isConnectable: device.isConnectable,
                                                 rssi: device.rssi,
                                                 name: device.name,
                                                 rssiImage: image))
        }
        view.viewModels = viewModels
    }
}

extension DfuDevicesScannerPresenter: DfuDevicesScannerViewOutput {
    func viewDidLoad() {
        view.isBluetoothEnabled = foreground.bluetoothState == .poweredOn
        if (!view.isBluetoothEnabled
            && foreground.bluetoothState != .unknown) ||
            !isBluetoothPermissionGranted {
            view.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
        }
    }

    func viewWillAppear() {
        startObservingBluetoothState()
        startObservingDfuDevices()
        startObservingLostDfuDevices()
    }

    func viewWillDisappear() {
        stopObservingBluetoothState()
        stopObservingDfuDevices()
        stopObservingLostDfuDevices()
    }

    func viewDidOpenFlashFirmware(uuid: String) {
        guard let dfuDevice = dfuDevices.first(where: {$0.uuid == uuid}) else {
            return
        }
        router.openFlashFirmware(dfuDevice)
    }
}

extension DfuDevicesScannerPresenter {
    private func startObservingBluetoothState() {
        bluetoothStateToken = foreground.state(self, closure: { (observer, state) in
            observer.view.isBluetoothEnabled = state == .poweredOn
            if state == .poweredOff || !self.isBluetoothPermissionGranted {
                observer.view.viewModels = []
                observer.view.showBluetoothDisabled(userDeclined: !self.isBluetoothPermissionGranted)
            }
        })
    }

    private func stopObservingBluetoothState() {
        bluetoothStateToken?.invalidate()
    }

    private func startObservingDfuDevices() {
        ruuviDfuScanToken = ruuviDfu.scan(self, closure: { observer, device in
            var devices = observer.dfuDevices
            if devices.contains(device) {
                devices.update(with: device)
            } else {
                devices.insert(device)
            }
            observer.dfuDevices = devices
        })
    }

    private func stopObservingDfuDevices() {
        ruuviDfuScanToken?.invalidate()
    }

    private func startObservingLostDfuDevices() {
        ruuviDfuLostToken = ruuviDfu.lost(self, closure: { observer, device in
            var devices = observer.dfuDevices
            if let index = devices.firstIndex(where: {$0.uuid == device.uuid}) {
                devices.remove(at: index)
                observer.dfuDevices = devices
            }
        })
    }

    private func stopObservingLostDfuDevices() {
        ruuviDfuLostToken?.invalidate()
    }
}
