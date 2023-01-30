import Foundation
import BTKit
import UIKit
import Future
import RuuviOntology
import RuuviContext
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviCore
import RuuviPresenters
import CoreBluetooth

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

    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var foreground: BTForeground!
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!
    var ruuviReactor: RuuviReactor!
    var ruuviOwnershipService: RuuviServiceOwnership!

    private weak var view: DiscoverViewInput?
    private var ruuviTags = Set<RuuviTag>()
    private var persistedSensors: [RuuviTagSensor]! {
        didSet {
            updateViewDevices()
        }
    }
    private var reloadTimer: Timer?
    private var scanToken: ObservationToken?
    private var stateToken: ObservationToken?
    private var lostToken: ObservationToken?
    private var persistedReactorToken: RuuviReactorToken?
    private lazy var ruuviLogoImage = UIImage.named("ruuvi_logo", for: Self.self)
    private var isBluetoothPermissionGranted: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        // Before iOS 13, Bluetooth permissions are not required
        return true
    }

    deinit {
        reloadTimer?.invalidate()
        scanToken?.invalidate()
        stateToken?.invalidate()
        lostToken?.invalidate()
        persistedReactorToken?.invalidate()
    }
}

// MARK: - DiscoverViewOutput
extension DiscoverPresenter: DiscoverViewOutput {
    func viewDidLoad() {
        view?.isBluetoothEnabled = foreground.bluetoothState == .poweredOn
        view?.isCloseEnabled = true
        startObservingPersistedRuuviSensors()
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

    func viewDidTriggerClose() {
        output?.ruuviDiscoverWantsClose(self)
    }

    func viewDidTriggerDisabledBTRow() {
        view?.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
    }

    func viewDidTriggerBuySensors() {
        guard let url = URL(string: "Ruuvi.BuySensors.URL.IOS".localized(for: Self.self))
        else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - Private
extension DiscoverPresenter {

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
            if state == .poweredOff || !self.isBluetoothPermissionGranted {
                observer.ruuviTags.removeAll()
                observer.view?.ruuviTags = []
                observer.view?.showBluetoothDisabled(userDeclined: !self.isBluetoothPermissionGranted)
            }
        })
    }

    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    private func startScanning() {
        scanToken = foreground.scan(self) { (observer, device) in
            if let ruuviTag = device.ruuvi?.tag {
                // when mode is changed, the device should be replaced
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
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true, block: { [weak self] (_) in
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
        let ruuviTags = ruuviTags.map { (ruuviTag) -> DiscoverRuuviTagViewModel in
            return DiscoverRuuviTagViewModel(
                luid: ruuviTag.luid?.any,
                isConnectable: ruuviTag.isConnectable,
                rssi: ruuviTag.rssi,
                mac: ruuviTag.mac,
                name: nil,
                logo: ruuviLogoImage
            )
        }
        view?.ruuviTags = visibleTags(ruuviTags: ruuviTags)
    }

    private func visibleTags(ruuviTags: [DiscoverRuuviTagViewModel]) -> [DiscoverRuuviTagViewModel] {
        let filtered = ruuviTags.filter({ tag in
            !persistedSensors.contains(where: { persistedTag in
                if let tagLuid = tag.luid?.value,
                    let persistedTagLuid = persistedTag.luid?.value {
                    return tagLuid == persistedTagLuid
                } else if let tagMacId = tag.mac,
                            let persistedTagMacId = persistedTag.macId?.value {
                    return tagMacId == persistedTagMacId
                } else {
                    return false
                }
            })
        }).sorted(by: {
            if let rssi0 = $0.rssi, let rssi1 = $1.rssi {
                return rssi0 > rssi1
            } else {
                return false
            }
        })

        return filtered
    }
}
