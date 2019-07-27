import Foundation
import BTKit
import RealmSwift

class DiscoverPresenter: DiscoverModuleInput {
    weak var view: DiscoverViewInput!
    var router: DiscoverRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var ruuviTagService: RuuviTagService!
    var webTagService: WebTagService!
    var scanner: BTScanner!
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    
    private var ruuviTags = Set<RuuviTag>()
    private var persistedRuuviTags: Results<RuuviTagRealm>! {
        didSet {
            view.savedDevicesUUIDs = persistedRuuviTags.map( { $0.uuid })
            updateCloseButtonVisibilityState()
        }
    }
    private var persistedWebTags: Results<WebTagRealm>! {
        didSet {
            view.savedWebTagProviders = persistedWebTags.map( { $0.provider } )
            updateCloseButtonVisibilityState()
        }
    }
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    private var lostToken: ObservationToken?
    private var persistedRuuviTagsToken: NotificationToken?
    private var persistedWebTagsToken: NotificationToken?
    private let ruuviLogoImage = UIImage(named: "ruuvi_logo")
    private var isOpenedFromWelcome: Bool = true
    
    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
        stateToken?.invalidate()
        lostToken?.invalidate()
        persistedRuuviTagsToken?.invalidate()
        persistedWebTagsToken?.invalidate()
    }
    
    func configure(isOpenedFromWelcome: Bool) {
        self.isOpenedFromWelcome = isOpenedFromWelcome
    }
}

// MARK: - DiscoverViewOutput
extension DiscoverPresenter: DiscoverViewOutput {
    func viewDidLoad() {
        view.webTags = [DiscoverWebTagViewModel(provider: .openWeatherMap)]
        view.isBluetoothEnabled = scanner.bluetoothState == .poweredOn
        if !view.isBluetoothEnabled && !isOpenedFromWelcome {
            view.showBluetoothDisabled()
        }
        startObservingPersistedRuuviTags()
        startObservingPersistedWebTags()
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
    
    func viewDidChoose(device: DiscoverDeviceViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.uuid == device.uuid }) {
            let operation = ruuviTagService.persist(ruuviTag: ruuviTag, name: ruuviTag.mac ?? ruuviTag.uuid)
            operation.on(success: { [weak self] (ruuviTag) in
                if let isOpenedFromWelcome = self?.isOpenedFromWelcome, isOpenedFromWelcome {
                    self?.router.openDashboard()
                } else {
                    self?.router.dismiss()
                }
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            })
        }
    }
    
    func viewDidChoose(webTag: DiscoverWebTagViewModel) {
        if permissionsManager.isLocationPermissionGranted {
            persistWebTag(with: webTag.provider)
        } else {
            permissionsManager.requestLocationPermission { [weak self] (granted) in
                if granted {
                    self?.persistWebTag(with: webTag.provider)
                } else {
                    self?.permissionPresenter.presentNoLocationPermission()
                }
            }
        }
    }
    
    func viewDidTriggerContinue() {
        if isOpenedFromWelcome {
            router.openDashboard()
        } else {
            router.dismiss()
        }
    }
    
    func viewDidTapOnGetMoreSensors() {
        router.openRuuviWebsite()
    }
    
    func viewDidTriggerClose() {
        if isOpenedFromWelcome {
            router.openDashboard()
        } else {
            router.dismiss()
        }
    }
}

// MARK: - Private
extension DiscoverPresenter {
    
    private func persistWebTag(with provider: WeatherProvider) {
        let operation = webTagService.add(provider: provider)
        operation.on(success: { [weak self] _ in
            if let isOpenedFromWelcome = self?.isOpenedFromWelcome, isOpenedFromWelcome {
                self?.router.openDashboard()
            } else {
                self?.router.dismiss()
            }
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }
    
    private func startObservingPersistedWebTags() {
        persistedWebTags = realmContext.main.objects(WebTagRealm.self)
        persistedWebTagsToken = persistedWebTags.observe({ [weak self] (change) in
            switch change {
            case .initial(let persistedWebTags):
                self?.persistedWebTags = persistedWebTags
            case .update(let persistedWebTags, _, _, _):
                self?.persistedWebTags = persistedWebTags
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }
    
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
        lostToken = scanner.lost(self, options: [.lostDeviceDelay(10)], closure: { (observer, device) in
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
                observer.view.showBluetoothDisabled()
            }
        })
    }
    
    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }
    
    private func startScanning() {
        scanToken = scanner.scan(self) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                // when mode is changed, the device dhould be replaced
                if let sameUUID = observer.ruuviTags.first(where: { $0.uuid == ruuviTag.uuid }), sameUUID != ruuviTag {
                    observer.ruuviTags.remove(sameUUID)
                }
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
    
    private func updateCloseButtonVisibilityState() {
        if persistedRuuviTags != nil && persistedWebTags != nil {
            view.isCloseEnabled = persistedRuuviTags.count > 0 || persistedWebTags.count > 0
        }
    }
}
