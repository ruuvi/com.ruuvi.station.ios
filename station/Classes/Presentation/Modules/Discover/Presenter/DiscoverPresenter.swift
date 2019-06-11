import Foundation
import BTKit

class DiscoverPresenter: DiscoverModuleInput {
    weak var view: DiscoverViewInput!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTags = Set<RuuviTag>()
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    
    deinit {
        scanToken?.invalidate()
        stateToken?.invalidate()
    }
}

// MARK: - DiscoverViewOutput
extension DiscoverPresenter: DiscoverViewOutput {
    func viewWillAppear() {
        startObservingBluetoothState()
        startScanning()
        startReloading()
    }
    
    func viewWillDisappear() {
        stopObservingBluetoothState()
        stopScanning()
        stopReloading()
    }
}

// MARK: - Private
extension DiscoverPresenter {
    private func startObservingBluetoothState() {
        stateToken = scanner.state(self, closure: { (observer, state) in
            if state == .poweredOff {
                // TODO: inform user that BT is disabled
            }
        })
    }
    
    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }
    
    private func startScanning() {
        scanToken = scanner.scan(self) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                observer.ruuviTags.update(with: ruuviTag)
            }
        }
    }
    
    private func stopScanning() {
        scanToken?.invalidate()
    }
    
    private func startReloading() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            guard let sSelf = self else { return }
            sSelf.view.ruuviTags = sSelf.ruuviTags.sorted(by: {$0.rssi > $1.rssi })
        })
    }
    
    private func stopReloading() {
        reloadTimer?.invalidate()
    }
}
