// swiftlint:disable file_length
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
import CoreBluetooth
import CoreNFC

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
    private var accessQueue = DispatchQueue(
        label: "com.ruuviDiscover.accessQueue", attributes: .concurrent
    )
    private var _persistedSensors: [RuuviTagSensor] = []
    private var persistedSensors: [RuuviTagSensor]! {
        get {
            return accessQueue.sync {
                _persistedSensors
            }
        }
        set {
            accessQueue.async(flags: .barrier) {
                self._persistedSensors = newValue
                DispatchQueue.main.async {
                    self.updateViewDevices()
                }
            }
        }
    }

    private var _ruuviTags = Set<RuuviTag>()
    private var ruuviTags: Set<RuuviTag> {
        get {
            return accessQueue.sync {
                _ruuviTags
            }
        }
        set {
            accessQueue.async(flags: .barrier) {
                self._ruuviTags = newValue
            }
        }
    }
    private var nfcSensor: NFCSensor?

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
            addRuuviTagOwnership(
                for: ruuviTag,
                displayName: displayName,
                firmwareVersion: nil
            )
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

    func viewDidTapUseNFC() {
        view?.startNFCSession()
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func viewDidReceiveNFCMessages(messages: [NFCNDEFMessage]) {
        // Stop NFC session
        view?.stopNFCSession()

        nfcSensor = NFCSensor(id: "", macId: "", firmwareVersion: "")
        // Parse the message
        for message in messages {
            for record in message.records {
                if let (key, value) = parse(record: record) {
                    switch key {
                    case "idID":
                        self.nfcSensor?.id = trimNulls(from: value)
                    case "adMAC":
                        self.nfcSensor?.macId = trimNulls(from: value)
                    case "swSW":
                        self.nfcSensor?.firmwareVersion = trimNulls(from: value)
                    default:
                        break
                    }
                }
            }
        }

        // Stop NFC session
        view?.stopNFCSession()

        // If tag is already added show the name from RuuviStation alongside
        // other info.
        if let addedTag = persistedSensors.first(where: { ruuviTag in
            ruuviTag.macId?.mac == nfcSensor?.macId
        }) {
            guard let message = self.message(
                for: nfcSensor,
                displayName: addedTag.name
            ) else { return }
            self.view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: message,
                showAddSensor: false,
                isDF3: false
            )
            return
        }

        // If tag is not added get the name from the mac and show other info.
        if let addableTag = ruuviTags.first(where: { ruuviTag in
            ruuviTag.mac == nfcSensor?.macId
        }) {
            guard let message = self.message(
                for: nfcSensor,
                displayName: self.displayName(for: nfcSensor)
            ) else { return }
            self.view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: message,
                showAddSensor: true,
                isDF3: false
            )
            return
        }

        // Got mac id from scan, but no match in the persisted tag or available tag.
        // which means either its a DF3 tag where mac id is not present or NFC scan
        // is done when sensor is not yet seen by BT.
        // Show info for DF3 case to add the tag using BT and update FW.
        // TODO: Discuss about the other case to handle it.
        guard let message = self.message(
            for: nfcSensor,
            displayName: self.displayName(for: nfcSensor)
        ) else { return }
        self.view?.showSensorDetailsDialog(
            for: nfcSensor,
            message: message,
            showAddSensor: false,
            isDF3: nfcSensor?.firmwareVersion == "2.5.9"
        )
    }

    func viewDidAddDeviceWithNFC(with tag: NFCSensor?) {
        guard let displayName = displayName(for: tag) else {
            return
        }
        if let ruuviTag = ruuviTags.first(where: { $0.mac != nil && $0.mac == tag?.macId }) {
            addRuuviTagOwnership(
                for: ruuviTag,
                displayName: displayName,
                firmwareVersion: tag?.firmwareVersion
            )
        }
    }

    func viewDidACopySensorDetails(with details: String?) {
        UIPasteboard.general.string = details
    }
}

 extension DiscoverPresenter {
    func onDidPick(location: Location) {
        virtualService.add(provider: .openWeatherMap, location: location)
            .on(success: { [weak self] virtualSensor in
                guard let sSelf = self else { return }
                sSelf.output?.ruuvi(discover: sSelf, didAdd: virtualSensor)
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
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
        reloadTimer = Timer.scheduledTimer(
            withTimeInterval: 3,
            repeats: true,
            block: { [weak self] (_) in
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

    /// Parse the NFC payload
    private func parse(record: NFCNDEFPayload) -> (String, String)? {
        let payload = record.payload
        let prefix = payload.prefix(1)
        let rest = payload.dropFirst(1)

        switch prefix {
        case .init([0x02]):
            guard let restString = String(
                data: rest, encoding: .utf8
            ) else { return nil }

            let components = restString.components(separatedBy: ": ")
            if components.count == 2 {
                let key = components[0]
                let value = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                return (key, value)
            }
        default:
            return nil
        }
        return nil
    }

    private func displayName(for tag: NFCSensor?) -> String? {
        guard let tag = tag else {
            return nil
        }
        return "DiscoverTable.RuuviDevice.prefix".localized(for: Self.self)
        + " " + tag.macId.replacingOccurrences(of: ":", with: "").suffix(4)
    }

    private func message(for tag: NFCSensor?, displayName: String?) -> String? {
        guard let tag = tag,
                let displayName = displayName else {
            return nil
        }

        let nameString = "\("name".localized(for: Self.self))\n\(displayName)"
        let macIdString = "\("mac_address".localized(for: Self.self))\n\(tag.macId)"
        let uniqueIdString = "\("unique_id".localized(for: Self.self))\n\(tag.id)"
        let fwString = "\("firmware_version".localized(for: Self.self))\n\(tag.firmwareVersion)"

        return "\n\(nameString)\n\n\(macIdString)\n\n\(uniqueIdString)\n\n\(fwString)\n".localized(for: Self.self)
    }

    private func addRuuviTagOwnership(
        for ruuviTag: RuuviTag,
        displayName: String,
        firmwareVersion: String?
    ) {
        ruuviOwnershipService.add(
            sensor: ruuviTag.with(name: displayName)
                .with(firmwareVersion: firmwareVersion ?? ""),
            record: ruuviTag.with(source: .advertisement))
            .on(success: { [weak self] anyRuuviTagSensor in
                guard let sSelf = self else { return }
                sSelf.output?.ruuvi(discover: sSelf, didAdd: anyRuuviTagSensor)
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    private func trimNulls(from string: String) -> String {
        return string.replacingOccurrences(of: "\0", with: "")
    }
}

extension DiscoverPresenter {
    // Will be deprecated in near future. Currently retained to support already
    // added web tags.
    private func persistWebTag(with provider: VirtualProvider) {
        let operation = virtualService.add(
            provider: provider,
            name: "Test Virtual Sensor"
        )
        operation.on(success: { [weak self] virtualSensor in
            guard let sSelf = self else { return }
            sSelf.output?.ruuvi(discover: sSelf, didAdd: virtualSensor)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }
}
// swiftlint:enable file_length
