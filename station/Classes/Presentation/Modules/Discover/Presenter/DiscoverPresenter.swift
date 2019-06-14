import Foundation
import BTKit
import RealmSwift

class DiscoverPresenter: DiscoverModuleInput {
    weak var view: DiscoverViewInput!
    var router: DiscoverRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    
    private let scanner = Ruuvi.scanner
    private var ruuviTags = Set<RuuviTag>()
    private var persistedRuuviTags: Results<RuuviTagRealm>!
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    private var lostToken: ObservationToken?
    private var persistedRuuviTagsToken: NotificationToken?
    private let ruuviLogoImage = UIImage(named: "ruuvi_logo")
    
    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
        stateToken?.invalidate()
        lostToken?.invalidate()
        persistedRuuviTagsToken?.invalidate()
    }
}

// MARK: - DiscoverViewOutput
extension DiscoverPresenter: DiscoverViewOutput {
    func viewDidLoad() {
        startObservingPersistedRuuviTags()
    }
    
    func viewWillAppear() {
        startObservingBluetoothState()
        startScanning()
        startReloading()
        startObservingLost()
    }
    
    func viewWillDisappear() {
        stopObservingBluetoothState()
        stopScanning()
        stopReloading()
        stopObservingLost()
    }
    
    func viewDidSelect(device: DiscoverDeviceViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.uuid == device.uuid }) {
            router.open(ruuviTag: ruuviTag)
        }
    }
}

// MARK: - Private
extension DiscoverPresenter {
    private func startObservingPersistedRuuviTags() {
        persistedRuuviTags = realmContext.main.objects(RuuviTagRealm.self)
        persistedRuuviTagsToken = persistedRuuviTags.observe { [weak self] (change) in
            switch change {
            case .initial(let persistedRuuviTags):
                self?.persistedRuuviTags = persistedRuuviTags
            case .update(let persistedRuuviTags, _, _, _):
                self?.persistedRuuviTags = persistedRuuviTags
                self?.updateViewDevices()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        }
    }
    
    private func startObservingLost() {
        lostToken = scanner.lost(self, closure: { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                observer.ruuviTags.remove(ruuviTag)
            }
        })
    }
    
    private func stopObservingLost() {
        lostToken?.invalidate()
    }
    
    private func startObservingBluetoothState() {
        stateToken = scanner.state(self, closure: { (observer, state) in
            observer.view.isBluetoothEnabled = state == .poweredOn
            if state == .poweredOff {
                observer.ruuviTags.removeAll()
                observer.view.devices = []
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
            self?.updateViewDevices()
        })
    }
    
    private func stopReloading() {
        reloadTimer?.invalidate()
    }
    
    private func updateViewDevices() {
        view.devices = ruuviTags.map { (ruuviTag) -> DiscoverDeviceViewModel in
            if let persistedRuuviTag = persistedRuuviTags.first(where: { $0.uuid == ruuviTag.uuid}) {
                return DiscoverDeviceViewModel(uuid: ruuviTag.uuid, rssi: ruuviTag.rssi, mac: ruuviTag.mac, name: persistedRuuviTag.name, logo: ruuviLogoImage)
            } else {
                return DiscoverDeviceViewModel(uuid: ruuviTag.uuid, rssi: ruuviTag.rssi, mac: ruuviTag.mac, name: nil, logo: ruuviLogoImage)
            }
        }
    }
}
