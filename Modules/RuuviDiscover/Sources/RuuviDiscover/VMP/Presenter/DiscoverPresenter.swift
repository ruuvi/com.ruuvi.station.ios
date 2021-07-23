import Foundation
import BTKit
import UIKit
import Future
import RuuviOntology
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviCore
import RuuviPresenters

class DiscoverPresenter: NSObject, RuuviDiscover {
    var viewController: UIViewController {
        if let view = view {
            return view
        } else {
            let storyboard = UIStoryboard.named("Discover", for: Self.self)
            // swiftlint:disable:next force_cast
            let view = storyboard.instantiateInitialViewController() as! DiscoverTableViewController
            view.output = self
            self.view = view
            return view
        }
    }

    var router: AnyObject?
    weak var output: RuuviDiscoverOutput?

    var virtualReactor: VirtualReactor!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var virtualService: VirtualService!
    var foreground: BTForeground!
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!
    var ruuviReactor: RuuviReactor!
    var ruuviOwnershipService: RuuviServiceOwnership!

    private weak var view: DiscoverViewInput?
    private var ruuviTags = Set<RuuviTag>()
    private var persistedVirtualSensors: [VirtualTagSensor]! {
        didSet {
            view?.savedWebTagProviders = persistedVirtualSensors.map({ $0.provider })
        }
    }
    private var persistedSensors: [RuuviTagSensor]! {
        didSet {
            view?.savedRuuviTagIds = persistedSensors.map({ $0.luid?.any })
        }
    }
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    private var lostToken: ObservationToken?
    private var virtualReactorToken: VirtualReactorToken?
    private var persistedReactorToken: RuuviReactorToken?
    private let ruuviLogoImage = UIImage(named: "ruuvi_logo")
    private var lastSelectedWebTag: DiscoverVirtualTagViewModel?

    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
        stateToken?.invalidate()
        lostToken?.invalidate()
        virtualReactorToken?.invalidate()
        persistedReactorToken?.invalidate()
    }
}

// MARK: - DiscoverViewOutput
extension DiscoverPresenter: DiscoverViewOutput {
    func viewDidLoad() {
        let current = DiscoverVirtualTagViewModel(
            provider: .openWeatherMap,
            locationType: .current,
            icon: UIImage(named: "icon-webtag-current")
        )
        let manual = DiscoverVirtualTagViewModel(
            provider: .openWeatherMap,
            locationType: .manual,
            icon: UIImage(named: "icon-webtag-map")
        )
        if virtualService.isCurrentLocationVirtualTagExists {
            view?.virtualTags = [manual]
        } else {
            view?.virtualTags = [manual, current]
        }
        view?.isBluetoothEnabled = foreground.bluetoothState == .poweredOn
        if !(view?.isBluetoothEnabled ?? false)
            && foreground.bluetoothState != .unknown {
            view?.showBluetoothDisabled()
        }

        view?.isCloseEnabled = true

        startObservingPersistedRuuviSensors()
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

    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String) {
        if let ruuviTag = ruuviTags.first(where: { $0.luid?.any != nil && $0.luid?.any == device.luid?.any }) {
            ruuviOwnershipService.add(
                sensor: ruuviTag.with(name: displayName),
                record: ruuviTag.with(source: .advertisement))
                .on(success: { [weak self] anyRuuviTagSensor in
                    guard let sSelf = self else { return }
                    sSelf.output?.ruuvi(discover: sSelf, didAdd: anyRuuviTagSensor)
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
        }
    }

    func viewDidChoose(webTag: DiscoverVirtualTagViewModel) {
        switch webTag.locationType {
        case .current:
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
        case .manual:
            lastSelectedWebTag = webTag
            output?.ruuviDiscoverWantsPickLocation(self)
        }
    }

    func viewDidTapOnGetMoreSensors() {
        output?.ruuviDiscoverWantsBuySensors(self)
    }

    func viewDidTriggerClose() {
        output?.ruuviDiscoverWantsClose(self)
    }

    func viewDidTapOnWebTagInfo() {
        view?.showWebTagInfoDialog()
    }
}

 extension DiscoverPresenter {
    func onDidPick(location: Location) {
        guard let webTag = lastSelectedWebTag else { return }
        virtualService.add(provider: webTag.provider, location: location)
            .on(success: { [weak self] virtualSensor in
                guard let sSelf = self else { return }
                sSelf.output?.ruuvi(discover: sSelf, didAdd: virtualSensor)
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        lastSelectedWebTag = nil
    }
 }

// MARK: - Private
extension DiscoverPresenter {
    private func persistWebTag(with provider: VirtualProvider) {
        let operation = virtualService.add(
            provider: provider,
            name: VirtualLocation.current.title
        )
        operation.on(success: { [weak self] virtualSensor in
            guard let sSelf = self else { return }
            sSelf.output?.ruuvi(discover: sSelf, didAdd: virtualSensor)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    private func startObservingPersistedWebTags() {
        virtualReactorToken?.invalidate()
        virtualReactorToken = virtualReactor.observe { [weak self] change in
            switch change {
            case .initial(let persistedVirtualSensors):
                self?.persistedVirtualSensors = persistedVirtualSensors
            case .insert(let addedPersistedVirtualSensor):
                self?.persistedVirtualSensors.append(addedPersistedVirtualSensor)
            case .delete(let deletedPersistedVirtualSensor):
                self?.persistedVirtualSensors.removeAll(where: { $0.id == deletedPersistedVirtualSensor.id })
            case .error(let error):
                self?.errorPresenter.present(error: error)
            case .update:
                break
            }
        }
    }

    private func startObservingPersistedRuuviSensors() {
        persistedReactorToken = ruuviReactor.observe({ [weak self] (change) in
            switch change {
            case .initial(let sensors):
                guard let sSelf = self else { return }
                self?.persistedSensors = sensors
            case .insert(let sensor):
                self?.persistedSensors.append(sensor)
            case .delete(let sensor):
                self?.persistedSensors.removeAll(where: {$0.any == sensor})
            default:
                return
            }
        })
    }

    private func startObservingLost() {
        lostToken = foreground.lost(self, options: [.lostDeviceDelay(10)], closure: { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                observer.ruuviTags.remove(ruuviTag)
            }
        })
    }

    private func stopObservingLost() {
        lostToken?.invalidate()
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
            observer.view?.isBluetoothEnabled = state == .poweredOn
            if state == .poweredOff {
                observer.ruuviTags.removeAll()
                observer.view?.ruuviTags = []
                observer.view?.showBluetoothDisabled()
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    private func startScanning() {
        scanToken = foreground.scan(self) { (observer, device) in
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
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { [weak self] (_) in
            self?.updateViewDevices()
        })
        // don't wait for timer, reload after 0.5 sec
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateViewDevices()
        }
    }

    private func stopReloading() {
        reloadTimer?.invalidate()
    }

    private func updateViewDevices() {
        view?.ruuviTags = ruuviTags.map { (ruuviTag) -> DiscoverRuuviTagViewModel in
            if let persistedRuuviTag = persistedSensors
                .first(where: { $0.luid?.any != nil && $0.luid?.any == ruuviTag.luid?.any }) {
                return DiscoverRuuviTagViewModel(
                    luid: ruuviTag.luid?.any,
                    isConnectable: ruuviTag.isConnectable,
                    rssi: ruuviTag.rssi,
                    mac: ruuviTag.mac,
                    name: persistedRuuviTag.name,
                    logo: ruuviLogoImage
                )
            } else {
                return DiscoverRuuviTagViewModel(
                    luid: ruuviTag.luid?.any,
                    isConnectable: ruuviTag.isConnectable,
                    rssi: ruuviTag.rssi,
                    mac: ruuviTag.mac,
                    name: nil,
                    logo: ruuviLogoImage
                )
            }
        }
    }
}
