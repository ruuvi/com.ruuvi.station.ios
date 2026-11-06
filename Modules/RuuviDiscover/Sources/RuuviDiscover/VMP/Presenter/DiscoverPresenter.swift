// swiftlint:disable file_length
import BTKit
import CoreBluetooth
import CoreNFC
import Foundation
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviDFU
import RuuviFirmware
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import UIKit

class DiscoverPresenter: NSObject, RuuviDiscover {
    var viewController: UIViewController {
        if let view {
            return view
        } else {
            let view = DiscoverTableViewController()
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
    var background: BTBackground!
    var propertiesDaemon: RuuviTagPropertiesDaemon!
    var ruuviDFU: RuuviDFU!
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!
    var ruuviReactor: RuuviReactor!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var firmwareBuilder: RuuviFirmwareBuilder!

    private let transportOverride: DiscoveryBluetoothTransport?
    private lazy var bluetooth: DiscoveryBluetoothTransport = transportOverride ?? BTKitDiscoveryTransport(foreground: foreground)
    private let permissionGranted: () -> Bool
    private let reloadInterval: TimeInterval
    private let initialReloadDelay: TimeInterval

    init(view: DiscoverViewInput? = nil, transport: DiscoveryBluetoothTransport? = nil,
        reloadInterval: TimeInterval = 3, initialReloadDelay: TimeInterval = 0.5,
        permissionGranted: @escaping () -> Bool = {
            CBManager.authorization != .denied && CBManager.authorization != .restricted
        }) {
        self.view = view
        self.transportOverride = transport
        self.reloadInterval = reloadInterval
        self.initialReloadDelay = initialReloadDelay
        self.permissionGranted = permissionGranted
        super.init()
    }

    private weak var firmwareModule: RuuviFirmware?
    private weak var view: DiscoverViewInput?
    // UIKit, Bluetooth callbacks and reactor snapshots share main-queue state.
    private var persistedSensors: [RuuviTagSensor] = [] {
        didSet { updateViewDevices() }
    }
    private var ruuviTags = Set<RuuviTag>()
    private var observationGeneration: UUID?
    private var persistedGeneration = UUID()

    private var nfcSensor: NFCSensor?

    private var reloadTimer: Timer?
    private var scanToken: (() -> Void)?
    private var stateToken: (() -> Void)?
    private var lostToken: (() -> Void)?
    private var persistedReactorToken: RuuviReactorToken?
    private var isBluetoothPermissionGranted: Bool { permissionGranted() }

    deinit {
        reloadTimer?.invalidate()
        scanToken?()
        stateToken?()
        lostToken?()
        persistedReactorToken?.invalidate()
    }
}

// MARK: - DiscoverViewOutput

extension DiscoverPresenter: DiscoverViewOutput {
    func viewDidLoad() {
        view?.isBluetoothEnabled = resolvedBluetoothState(for: bluetooth.state).isEnabled
        view?.isCloseEnabled = true
        startObservingPersistedRuuviSensors()
    }

    func viewWillAppear() {
        viewWillDisappear()
        observationGeneration = UUID()
        startObservingBluetoothState()
        startScanning()
        startReloading()
        startObservingLost()
    }

    func viewWillDisappear() {
        observationGeneration = nil
        stopObservingBluetoothState()
        stopScanning()
        stopReloading()
        stopObservingLost()
    }

    func viewDidChoose(device: DiscoverRuuviTagViewModel, displayName: String) {
        if let ruuviTag = ruuviTags.first(where: { $0.luid?.any != nil && $0.luid?.any == device.luid?.any }) {
            if device.mac != nil {
                addRuuviTagOwnership(
                    sensor: ruuviTag.with(name: displayName),
                    record: ruuviTag.with(source: .advertisement),
                    displayName: displayName,
                    firmwareVersion: nil
                )
            } else {
                view?.showUpdateFirmwareDialog(for: ruuviTag.uuid)
            }
        }
    }

    func viewDidTriggerClose() {
        output?.ruuviDiscoverWantsClose(self)
    }

    func viewDidTriggerDisabledBTRow() {
        let resolvedState = resolvedBluetoothState(for: bluetooth.state)
        view?.showBluetoothDisabled(userDeclined: resolvedState.userDeclined)
    }

    func viewDidTriggerBuySensors() {
        guard let url = URL(string: RuuviLocalization.Ruuvi.BuySensors.Url.ios)
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
                        nfcSensor?.id = trimNulls(from: value)
                    case "adMAC":
                        nfcSensor?.macId = trimNulls(from: value)
                    case "swSW":
                        nfcSensor?.firmwareVersion = trimNulls(from: value)
                    default:
                        break
                    }
                }
            }
        }

        // Stop NFC session
        view?.stopNFCSession()

        guard
            let message = self.message(
                for: nfcSensor,
                displayName: displayName(for: nfcSensor)
            )
        else { return }

        // If tag is already added show the name from RuuviStation alongside
        // other info.
        if let addedTag = persistedSensors.first(where: { ruuviTag in
            ruuviTag.macId?.any == nfcSensor?.macId.mac.any
        }) {
            view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: self.message(
                    for: nfcSensor,
                    displayName: addedTag.name
                ) ?? message,
                showAddSensor: false,
                showGoToSensor: true,
                showUpgradeFirmware: false,
                isDF3: false
            )
            return
        }

        // If tag is not added get the name from the mac and show other info.
        if ruuviTags.first(where: { ruuviTag in
            ruuviTag.mac == nfcSensor?.macId
        }) != nil {
            view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: message,
                showAddSensor: true,
                showGoToSensor: false,
                showUpgradeFirmware: false,
                isDF3: false
            )
            return
        }

        if nfcSensor?.firmwareVersion == "2.5.9" {
            view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: message,
                showAddSensor: false,
                showGoToSensor: false,
                showUpgradeFirmware: true,
                isDF3: true
            )
        } else {
            view?.showSensorDetailsDialog(
                for: nfcSensor,
                message: message,
                showAddSensor: canAddSensorFromNFC(nfcSensor),
                showGoToSensor: false,
                showUpgradeFirmware: false,
                isDF3: false
            )
        }
    }

    func viewDidAddDeviceWithNFC(with tag: NFCSensor?) {
        guard let tag,
            canAddSensorFromNFC(tag),
            let displayName = displayName(for: tag)
        else {
            return
        }
        if let ruuviTag = ruuviTags.first(where: { $0.mac != nil && $0.mac == tag.macId }) {
            addRuuviTagOwnership(
                sensor: ruuviTag.with(name: displayName),
                record: ruuviTag.with(source: .advertisement),
                displayName: displayName,
                firmwareVersion: tag.firmwareVersion
            )
        } else {
            addRuuviTagOwnership(
                sensor: nfcPersistedSensor(for: tag, displayName: displayName),
                record: nil,
                displayName: displayName,
                firmwareVersion: tag.firmwareVersion
            )
        }
    }

    func viewDidGoToSensor(with sensor: NFCSensor?) {
        if let ruuviTag = persistedSensors.first(where: { ruuviTag in
            ruuviTag.macId?.any == sensor?.macId.mac.any
        }) {
            output?.ruuvi(discover: self, didSelectFromNFC: ruuviTag)
        }
    }

    func viewDidAskToUpgradeFirmware(of sensor: NFCSensor?) {
        guard let sensor else { return }
        let firmwareModule = firmwareBuilder.build(
            uuid: sensor.id,
            currentFirmware: sensor.firmwareVersion.ruuviFirmwareDisplayValue,
            dependencies: RuuviFirmwareDependencies(
                background: background,
                foreground: foreground,
                propertiesDaemon: propertiesDaemon,
                ruuviDFU: ruuviDFU
            )
        )
        firmwareModule.output = self
        viewController.present(firmwareModule.viewController, animated: true)
        self.firmwareModule = firmwareModule
    }

    func viewDidACopyMacAddress(of sensor: NFCSensor?) {
        UIPasteboard.general.string = sensor?.macId
    }

    func viewDidACopySecret(of sensor: NFCSensor?) {
        UIPasteboard.general.string = sensor?.id
    }

    func viewDidConfirmToUpdateFirmware(for uuid: String) {
        let firmwareModule = firmwareBuilder.build(
            uuid: uuid,
            currentFirmware: "<=2.5.9",
            dependencies: RuuviFirmwareDependencies(
                background: background,
                foreground: foreground,
                propertiesDaemon: propertiesDaemon,
                ruuviDFU: ruuviDFU
            )
        )
        firmwareModule.output = self
        let firmwareViewController = firmwareModule.viewController
        firmwareViewController.presentationController?.delegate = self
        viewController.present(firmwareViewController, animated: true)
        self.firmwareModule = firmwareModule
    }
}

extension DiscoverPresenter: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        guard presentationController.presentedViewController == firmwareModule?.viewController else {
            return true
        }
        guard let firmwareModule, !firmwareModule.isSafeToDismiss() else {
            return true
        }
        return false
    }
}

// MARK: - RuuviFirmwareOutput

extension DiscoverPresenter: RuuviFirmwareOutput {
    func ruuviFirmwareSuccessfullyUpgraded(_ ruuviDiscover: RuuviFirmware) {
        ruuviDiscover.viewController.dismiss(animated: true)
    }
}

// MARK: - Private

extension DiscoverPresenter {
    private func startObservingPersistedRuuviSensors() {
        persistedReactorToken?.invalidate()
        let generation = UUID()
        persistedGeneration = generation
        persistedReactorToken = ruuviReactor.observe { [weak self] change in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.persistedGeneration == generation else { return }
                switch change {
                case let .initial(sensors): self.persistedSensors = sensors
                case let .insert(sensor):
                    self.persistedSensors.removeAll { $0.id == sensor.id }
                    self.persistedSensors.append(sensor)
                case let .update(sensor):
                    if let index = self.persistedSensors.firstIndex(where: { $0.id == sensor.id }) {
                        self.persistedSensors[index] = sensor
                    }
                case let .delete(sensor): self.persistedSensors.removeAll { $0.id == sensor.id }
                case .error: break
                }
            }
        }
    }

    private func whileObserving(_ generation: UUID?, perform action: @escaping (DiscoverPresenter) -> Void) {
        let deliver = { [weak self] in
            guard let self, let generation, self.observationGeneration == generation else { return }
            action(self)
        }
        if Thread.isMainThread { deliver() } else { DispatchQueue.main.async(execute: deliver) }
    }

    private func startObservingLost() {
        let generation = observationGeneration
        lostToken = bluetooth.observeLost { [weak self] tag in
            self?.whileObserving(generation) { $0.ruuviTags.remove(tag) }
        }
    }

    private func stopObservingLost() {
        lostToken?()
        lostToken = nil
    }

    private func startObservingBluetoothState() {
        let generation = observationGeneration
        stateToken = bluetooth.observeState { [weak self] state in
            self?.whileObserving(generation) { observer in
                let resolvedState = observer.resolvedBluetoothState(for: state)
                observer.view?.isBluetoothEnabled = resolvedState.isEnabled
                if !resolvedState.isEnabled || resolvedState.userDeclined {
                    observer.ruuviTags.removeAll()
                    observer.view?.ruuviTags = []
                    observer.view?.showBluetoothDisabled(userDeclined: resolvedState.userDeclined)
                }
            }
        }
    }

    private func stopObservingBluetoothState() {
        stateToken?()
        stateToken = nil
    }

    private func resolvedBluetoothState(for state: BTScannerState) -> (isEnabled: Bool, userDeclined: Bool) {
        let permissionDenied = !isBluetoothPermissionGranted || state == .unauthorized

        if permissionDenied {
            let isEnabled = state == .poweredOn
            return (isEnabled, true)
        }

        switch state {
        case .poweredOff,
            .unsupported:
            return (false, false)
        default:
            return (true, false)
        }
    }

    private func startScanning() {
        let generation = observationGeneration
        scanToken = bluetooth.scan { [weak self] tag in
            self?.whileObserving(generation) { observer in
                if let previous = observer.ruuviTags.first(where: {
                    $0.uuid == tag.uuid || (tag.macId != nil && $0.mac?.mac.any == tag.macId?.any)
                }), previous != tag {
                    observer.ruuviTags.remove(previous)
                }
                observer.ruuviTags.update(with: tag)
            }
        }
    }

    private func stopScanning() {
        scanToken?()
        scanToken = nil
    }

    private func startReloading() {
        reloadTimer = Timer.scheduledTimer(
            withTimeInterval: reloadInterval,
            repeats: true,
            block: { [weak self] _ in
                self?.updateViewDevices()
            }
        )
        let generation = observationGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + initialReloadDelay) { [weak self] in
            self?.whileObserving(generation) { $0.updateViewDevices() }
        }
    }

    private func stopReloading() {
        reloadTimer?.invalidate()
        reloadTimer = nil
    }

    private func updateViewDevices() {
        let ruuviTags = ruuviTags.map { ruuviTag -> DiscoverRuuviTagViewModel in
            DiscoverRuuviTagViewModel(
                luid: ruuviTag.luid?.any,
                isConnectable: ruuviTag.isConnectable,
                rssi: ruuviTag.rssi,
                mac: ruuviTag.mac,
                name: nil,
                logo: RuuviAsset.ruuviLogo.image,
                dataFormat: ruuviTag.version
            )
        }
        view?.ruuviTags = visibleTags(ruuviTags: ruuviTags)
    }

    private func visibleTags(ruuviTags: [DiscoverRuuviTagViewModel]) -> [DiscoverRuuviTagViewModel] {
        let filtered = ruuviTags.filter { tag in
            !persistedSensors.contains(where: { persistedTag in
                let sameLuid = tag.luid != nil && tag.luid?.value == persistedTag.luid?.value
                let sameMac = tag.mac != nil && tag.mac?.mac.any == persistedTag.macId?.any
                return sameLuid || sameMac
            })
        }.sorted(by: {
            if let rssi0 = $0.rssi, let rssi1 = $1.rssi {
                rssi0 > rssi1
            } else {
                false
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
            guard
                let restString = String(
                    data: rest, encoding: .utf8
                )
            else { return nil }

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
        guard let tag
        else {
            return nil
        }

        if isRuuviAir(tag) {
            return Helpers.ruuviAirDefaultName(from: tag.macId)
        }

        return
            Helpers
            .ruuviDeviceDefaultName(
                from: tag.macId,
                luid: nil,
                dataFormat: nil
            )
    }

    private func message(for tag: NFCSensor?, displayName: String?) -> String? {
        guard let tag,
            let displayName
        else {
            return nil
        }

        let nameString = "\(RuuviLocalization.name)\n\(displayName)"
        let macIdString = "\(RuuviLocalization.macAddress)\n\(tag.macId)"
        let uniqueIdString = "\(RuuviLocalization.uniqueId)\n\(tag.id)"
        let firmwareVersion = tag.firmwareVersion.ruuviFirmwareDisplayValue
        let fwString = "\(RuuviLocalization.firmwareVersion)\n\(firmwareVersion)"

        return "\n\(nameString)\n\n\(macIdString)\n\n\(uniqueIdString)\n\n\(fwString)\n"
    }

    private func canAddSensorFromNFC(_ tag: NFCSensor?) -> Bool {
        guard let tag else { return false }
        return !tag.macId.isEmpty
    }

    private func isRuuviAir(_ tag: NFCSensor) -> Bool {
        let normalizedFirmwareVersion = tag.firmwareVersion
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let normalizedReference = RuuviLocalization.ruuviAir
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        return normalizedFirmwareVersion.contains(normalizedReference)
    }

    private func nfcPersistedSensor(
        for tag: NFCSensor,
        displayName: String
    ) -> RuuviTagSensor {
        RuuviTagSensorStruct(
            // NFC payload does not include the BT data format.
            // Persist an unknown value until Bluetooth later updates the sensor.
            version: 0,
            firmwareVersion: tag.firmwareVersion.ruuviFirmwareDisplayValue,
            luid: nil,
            macId: tag.macId.mac,
            serviceUUID: nil,
            isConnectable: false,
            name: displayName,
            isClaimed: false,
            isOwner: true,
            owner: nil,
            ownersPlan: nil,
            isCloudSensor: false,
            canShare: false,
            sharedTo: [],
            sharedToPending: [],
            maxHistoryDays: nil
        )
    }

    private func addRuuviTagOwnership(
        sensor: RuuviTagSensor,
        record: RuuviTagSensorRecord?,
        displayName: String,
        firmwareVersion: String?
    ) {
        let sanitizedFirmware = firmwareVersion?.ruuviFirmwareDisplayValue ?? firmwareVersion ?? ""

        Task { @MainActor [self] in
            do throws(RuuviServiceError) {
                let value = try await ruuviOwnershipService.add(
                    sensor: sensor.with(name: displayName)
                        .with(firmwareVersion: sanitizedFirmware),
                    record: record
                )
                ({ [weak self] anyRuuviTagSensor in
                    guard let sSelf = self else { return }
                    sSelf.output?.ruuvi(discover: sSelf, didAdd: anyRuuviTagSensor)
                })(value)
            } catch {
                ({ [weak self] error in
                    self?.errorPresenter.present(error: error)
                })(error)
            }
        }
    }

    private func trimNulls(from string: String) -> String {
        string.replacingOccurrences(of: "\0", with: "")
    }
}

// swiftlint:enable file_length
