// swiftlint:disable file_length
import Foundation
import BTKit
import UIKit
import Future
import RuuviOntology
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviUser
import RuuviCore
import RuuviPresenters
import RuuviPool
import RuuviNotifier
import RuuviDaemon

class TagSettingsPresenter: NSObject, TagSettingsModuleInput {

    weak var view: TagSettingsViewInput!
    weak var output: TagSettingsModuleOutput?
    var router: TagSettingsRouterInput!
    var errorPresenter: ErrorPresenter!
    var foreground: BTForeground!
    var background: BTBackground!
    var alertService: RuuviServiceAlert!
    var settings: RuuviLocalSettings!
    var connectionPersistence: RuuviLocalConnections!
    var pushNotificationsManager: RuuviCorePN!
    var permissionPresenter: PermissionPresenter!
    var ruuviPool: RuuviPool!
    var ruuviStorage: RuuviStorage!
    var ruuviReactor: RuuviReactor!
    var ruuviUser: RuuviUser!
    var activityPresenter: ActivityPresenter!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var featureToggleService: FeatureToggleService!
    var exportService: RuuviServiceExport!
    var localSyncState: RuuviLocalSyncState!
    var alertHandler: RuuviNotifier!
    var advertisementDaemon: RuuviTagAdvertisementDaemon!
    var heartbeatDaemon: RuuviTagHeartbeatDaemon!

    private static let lowUpperDebounceDelay: TimeInterval = 0.3

    private var ruuviTag: RuuviTagSensor! {
        didSet {
            syncViewModel()
            bindViewModel()
        }
    }
    private var sensorSettings: SensorSettings? {
        didSet {
            syncOffsetCorrection()
        }
    }

    private var viewModel: TagSettingsViewModel!
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagSensorRecordToken: RuuviReactorToken?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var connectToken: NSObjectProtocol?
    private var disconnectToken: NSObjectProtocol?
    private var appDidBecomeActiveToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var mutedTillTimer: Timer?
    private var exportFileUrl: URL?
    private var previousAdvertisementSequence: Int?
    private var lastMeasurement: RuuviTagSensorRecord? {
        didSet {
            syncOffsetCorrection()
        }
    }
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }

    private var timer: Timer?

    deinit {
        lastMeasurement = nil
        mutedTillTimer?.invalidate()
        ruuviTagToken?.invalidate()
        ruuviTagSensorRecordToken?.invalidate()
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        alertDidChangeToken?.invalidate()
        backgroundToken?.invalidate()
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    func configure(ruuviTag: RuuviTagSensor,
                   latestMeasurement: RuuviTagSensorRecord?,
                   sensorSettings: SensorSettings?) {

        self.viewModel = TagSettingsViewModel()
        self.lastMeasurement = latestMeasurement
        if let sensorSettings = sensorSettings {
            self.sensorSettings = sensorSettings
        } else {
            self.sensorSettings = SensorSettingsStruct(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                temperatureOffset: nil,
                temperatureOffsetDate: nil,
                humidityOffset: nil,
                humidityOffsetDate: nil,
                pressureOffset: nil,
                pressureOffsetDate: nil
            )
        }
        self.ruuviTag = ruuviTag

        bindViewModel(to: ruuviTag)
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingRuuviTagSensor(ruuviTag: ruuviTag)
        startObservingSettingsChanges()
        startObservingConnectionStatus()
        startObservingApplicationState()
        startObservingAlertChanges()
        startMutedTillTimer()
        startListeningToRuuviTagsAlertStatus()
        processAlerts()
    }

    func configure(output: TagSettingsModuleOutput) {
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        router.dismiss(completion: completion)
    }
}

// MARK: - TagSettingsViewOutput
extension TagSettingsPresenter: TagSettingsViewOutput {
    func viewDidLoad() {
        startSubscribeToBackgroundUploadProgressChanges()
        startObservingAppState()
    }

    func viewWillAppear() {
        checkPushNotificationsStatus()
        checkLastSensorSettings()
    }

    private func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(handleAppEnterForgroundState),
                         name: UIApplication.willEnterForegroundNotification,
                         object: nil)
        NotificationCenter
            .default
            .addObserver(self,
                         selector: #selector(handleAppEnterBackgroundState),
                         name: UIApplication.didEnterBackgroundNotification,
                         object: nil)
    }

    @objc private func handleAppEnterForgroundState() {
        syncAlerts()
        if let keep = viewModel.keepConnection.value,
           let connected = viewModel.isConnected.value {
            if keep && !connected {
                view.startKeepConnectionAnimatingDots()
            }
        }
    }

    @objc private func handleAppEnterBackgroundState() {
        if let keep = viewModel.keepConnection.value,
           let connected = viewModel.isConnected.value {
            if keep && !connected {
                view.stopKeepConnectionAnimatingDots()
            }
        }
    }

    func viewDidAskToDismiss() {
        output?.tagSettingsDidDismiss(module: self)
    }

    func viewDidTriggerChangeBackground() {
        router.openBackgroundSelectionView(ruuviTag: ruuviTag)
    }

    func viewDidTriggerKeepConnection(isOn: Bool) {
        if settings.cloudModeEnabled && ruuviTag.isCloud {
            if isOn {
                view.showKeepConnectionCloudModeDialog()
            } else {
                viewModel.keepConnection.value = isOn
            }
        } else {
            viewModel.keepConnection.value = isOn
            if isOn {
                setupTimeoutTimerForKeepConnection()
            } else {
                invalidateTimer()
            }
        }
    }

    func viewDidAskToRemoveRuuviTag() {
        if viewModel.isClaimedTag.value == true && ruuviTag.isOwner {
            view.showUnclaimAndRemoveConfirmationDialog()
        } else {
            view.showTagRemovalConfirmationDialog(isOwner: ruuviTag.isOwner)
        }
    }

    func viewDidConfirmTagRemoval() {
        ruuviOwnershipService.remove(sensor: ruuviTag).on(success: { [weak self] _ in
            guard let sSelf = self else { return }
            // Disconnect the sensor first if paired.
            // Otherwise proceed to removal directly.
            if let luid = sSelf.ruuviTag.luid,
               let isConnected = sSelf.viewModel.isConnected.value,
               isConnected {
                sSelf.connectionPersistence.setKeepConnection(false, for: luid)
                sSelf.heartbeatDaemon.restart()
            }

            if sSelf.ruuviTag.isOwner {
                sSelf.advertisementDaemon.restart()
                if let isConnected = sSelf.viewModel.isConnected.value,
                isConnected {
                    sSelf.heartbeatDaemon.restart()
                }
            }
            sSelf.viewModel.reset()
            sSelf.localSyncState.setSyncDate(nil, for: sSelf.ruuviTag.macId)
            sSelf.localSyncState.setGattSyncDate(nil, for: sSelf.ruuviTag.macId)
            sSelf.output?.tagSettingsDidDeleteTag(module: sSelf,
                                                 ruuviTag: sSelf.ruuviTag)
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        })
    }

    func viewDidChangeTag(name: String) {
        let finalName = name.isEmpty ? (ruuviTag.macId?.value ?? ruuviTag.id) : name
        ruuviSensorPropertiesService.set(name: finalName, for: ruuviTag)
            .on(failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    func viewDidTapOnMacAddress() {
        if viewModel.mac.value != nil {
            view.showMacAddressDetail()
        } else {
            viewDidTriggerFirmwareUpdateDialog()
        }
    }

    func viewDidTriggerFirmwareUpdateDialog() {
        guard let luid = ruuviTag.luid else {
            return
        }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view.showFirmwareUpdateDialog()
        }
    }

    func viewDidConfirmFirmwareUpdate() {
        guard ruuviTag.luid != nil else {
            return
        }
        router.openUpdateFirmware(ruuviTag: ruuviTag)
    }

    func viewDidIgnoreFirmwareUpdateDialog() {
        view.showFirmwareDismissConfirmationUpdateDialog()
    }

    func viewDidTapOnTxPower() {
        if viewModel.txPower.value == nil {
            viewDidTriggerFirmwareUpdateDialog()
        }
    }

    func viewDidTapOnMeasurementSequenceNumber() {
        if viewModel.measurementSequenceNumber.value == nil {
            viewDidTriggerFirmwareUpdateDialog()
        }
    }

    func viewDidTapOnNoValuesView() {
        viewDidTriggerFirmwareUpdateDialog()
    }

    func viewDidTapClaimButton() {
        if viewModel.isClaimedTag.value == true {
            isLoading = true
            ruuviOwnershipService
                .unclaim(sensor: ruuviTag)
                .on(success: { [weak self] unclaimedSensor in
                    self?.ruuviTag = unclaimedSensor
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                }, completion: { [weak self] in
                    self?.isLoading = false
                })
        } else {
            isLoading = true
            ruuviOwnershipService
                .claim(sensor: ruuviTag)
                .on(success: { [weak self] claimedSensor in
                    self?.ruuviTag = claimedSensor
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                }, completion: { [weak self] in
                    self?.isLoading = false
                })
        }
    }

    func viewDidTapShareButton() {
        router.openShare(for: ruuviTag)
    }

    func viewDidTapTemperatureOffsetCorrection() {
        router.openOffsetCorrection(type: .temperature, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapHumidityOffsetCorrection() {
        router.openOffsetCorrection(type: .humidity, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapOnPressureOffsetCorrection() {
        router.openOffsetCorrection(type: .pressure, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
    }

    func viewDidTapOnUpdateFirmware() {
        router.openUpdateFirmware(ruuviTag: ruuviTag)
    }

    func viewDidTapOnExport() {
        view.showCSVExportLocationDialog()
    }

    func viewDidTapOnOwner() {
        guard let isOwner = viewModel.isOwner.value, isOwner else { return }
        if viewModel.isClaimedTag.value == false {
            router.openOwner(ruuviTag: ruuviTag)
        }
    }
}

// MARK: - Private
extension TagSettingsPresenter {
    private func startMutedTillTimer() {
        self.mutedTillTimer = Timer
            .scheduledTimer(
                withTimeInterval: 5,
                repeats: true
            ) { [weak self] timer in
                guard let sSelf = self else { timer.invalidate(); return }
                sSelf.reloadMutedTill()
            }
    }

    private func startListeningToRuuviTagsAlertStatus() {
        if ruuviTag.isCloud && settings.cloudModeEnabled {
            if let macId = ruuviTag.macId {
                alertHandler.subscribe(self, to: macId.value)
            }
        } else {
            if let luid = ruuviTag.luid {
                alertHandler.subscribe(self, to: luid.value)
            } else if let macId = ruuviTag.macId {
                alertHandler.subscribe(self, to: macId.value)
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func syncViewModel() {
        viewModel.temperatureUnit.value = settings.temperatureUnit
        viewModel.humidityUnit.value = settings.humidityUnit
        viewModel.pressureUnit.value = settings.pressureUnit
        ruuviSensorPropertiesService.getImage(for: ruuviTag)
            .on(success: { [weak self] image in
                self?.viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: ruuviTag)
        viewModel.relativeHumidityAlertDescription.value = alertService.relativeHumidityDescription(for: ruuviTag)
        viewModel.humidityAlertDescription.value = alertService.humidityDescription(for: ruuviTag)
        viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: ruuviTag)
        viewModel.signalAlertDescription.value = alertService.signalDescription(for: ruuviTag)
        viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: ruuviTag)
        viewModel.movementAlertDescription.value = alertService.movementDescription(for: ruuviTag)
        viewModel.isAuthorized.value = ruuviUser.isAuthorized
        viewModel.canShareTag.value = ruuviTag.isOwner && ruuviTag.isClaimed

        // swiftlint:disable line_length
        // Context:
        // The tag can be claimable only when -
        // 1: When - the tag is not claimed already, AND
        // 2: When - the tag macId is not Nil, AND
        // 3: When - there's no owner of the tag OR there's a owner of the tag but it's not the logged in user
        // Last one is for the scenario when a tag is added locally but claimed by other user
        let canBeClaimed = !ruuviTag.isClaimed && ruuviTag.macId != nil && (ruuviTag.owner == nil || (ruuviTag.owner != nil && ruuviTag.isOwner))
        viewModel.canClaimTag.value = canBeClaimed
        viewModel.isClaimedTag.value = !canBeClaimed

        // Not set / Someone else / email of the one who shared the sensor with you / You
        if let owner = ruuviTag.owner {
            viewModel.owner.value = owner
        } else {
            viewModel.owner.value = "TagSettings.General.Owner.none".localized()
        }
        // Set isOwner value
        viewModel.isOwner.value = ruuviTag.isOwner

        if (ruuviTag.name == ruuviTag.luid?.value
            || ruuviTag.name == ruuviTag.macId?.value)
            && !ruuviTag.isCloud {
            viewModel.name.value = nil
        } else {
            viewModel.name.value = ruuviTag.name
        }

        viewModel.isConnectable.value = ruuviTag.isConnectable && ruuviTag.luid != nil && ruuviTag.isOwner

        viewModel.isNetworkConnected.value = ruuviTag.isCloud
        if let luid = ruuviTag.luid {
            viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            viewModel.keepConnection.value = connectionPersistence.keepConnection(to: luid)
        } else {
            viewModel.isConnected.value = false
            viewModel.keepConnection.value = false
        }
        if let macId = ruuviTag.macId?.value {
            viewModel.mac.value = macId
        }
        viewModel.uuid.value = ruuviTag.luid?.value ?? ruuviTag.macId?.value
        viewModel.version.value = ruuviTag.version
        viewModel.firmwareVersion.value = ruuviTag.firmwareVersion

        viewModel.humidityOffsetCorrectionVisible.value = !(lastMeasurement?.humidity == nil)
        viewModel.pressureOffsetCorrectionVisible.value = !(lastMeasurement?.pressure == nil)

        viewModel.temperature.value = lastMeasurement?.temperature
        viewModel.humidity.value = lastMeasurement?.humidity
        viewModel.movementCounter.value = lastMeasurement?.movementCounter

        syncAlerts()

        view.viewModel = viewModel
    }

    private func bindViewModel() {
        // isPNAlertsAvailiable
        let isPNEnabled = viewModel.isPushNotificationsEnabled
        let isConnectable = viewModel.isConnectable

        bind(viewModel.isConnectable) { [weak isPNEnabled] observer, isConnectable in
            let isPN = isPNEnabled?.value ?? false
            let isCo = isConnectable ?? false
            let isEnabled = isPN && isCo
            observer.viewModel.isPNAlertsAvailiable.value = isEnabled
        }

        bind(viewModel.isPushNotificationsEnabled) {
            [weak isConnectable] observer, isPushNotificationsEnabled in
            let isPN = isPushNotificationsEnabled ?? false
            let isCo = isConnectable?.value ?? false
            let isEnabled = isPN && isCo
            observer.viewModel.isPNAlertsAvailiable.value = isEnabled
        }

        // isCloudAlertsAvailable
        bind(viewModel.isNetworkConnected) { observer, isNetworkConnected in
            let isCloud = isNetworkConnected ?? false
            observer.viewModel.isCloudAlertsAvailable.value = isCloud
        }

        // isAlertsVisible
        let isCloudAlertsAvailable = viewModel.isCloudAlertsAvailable

        // isAlertsEnabled
        bind(viewModel.isConnected) { [weak isCloudAlertsAvailable] observer, isConnected in
            let isCl = isCloudAlertsAvailable?.value ?? false
            let isCo = isConnected ?? false
            observer.viewModel.isAlertsEnabled.value = isCl || isCo
            self.processAlerts()
        }

        let isConnected = viewModel.isConnected
        bind(viewModel.isCloudAlertsAvailable) { [weak isConnected] observer, isCloudAlertsAvailable in
            let isCl = isCloudAlertsAvailable ?? false
            let isCo = isConnected?.value ?? false
            observer.viewModel.isAlertsEnabled.value = isCl || isCo
            self.processAlerts()
        }
    }

    private func syncOffsetCorrection() {
        // reload offset correction
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset

        viewModel.humidityOffsetCorrectionVisible.value = !(lastMeasurement?.humidity == nil)
        viewModel.pressureOffsetCorrectionVisible.value = !(lastMeasurement?.pressure == nil)
    }

    private func syncAlerts() {
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                sync(temperature: type, ruuviTag: ruuviTag)
            case .relativeHumidity:
                sync(relativeHumidity: type, ruuviTag: ruuviTag)
            case .humidity:
                sync(humidity: type, ruuviTag: ruuviTag)
            case .pressure:
                sync(pressure: type, ruuviTag: ruuviTag)
            case .signal:
                sync(signal: type, ruuviTag: ruuviTag)
            case .connection:
                sync(connection: type, ruuviTag: ruuviTag)
            case .movement:
                sync(movement: type, ruuviTag: ruuviTag)
            }
        }
    }

    private func sync(temperature: AlertType, ruuviTag: RuuviTagSensor) {
        if case .temperature(let lower, let upper) = alertService.alert(for: ruuviTag, of: temperature) {
            viewModel.isTemperatureAlertOn.value = true
            viewModel.temperatureLowerBound.value = Temperature(Double(lower), unit: .celsius)
            viewModel.temperatureUpperBound.value = Temperature(Double(upper), unit: .celsius)
        } else {
            viewModel.isTemperatureAlertOn.value = false
            if let celsiusLower = alertService.lowerCelsius(for: ruuviTag) {
                viewModel.temperatureLowerBound.value = Temperature(Double(celsiusLower), unit: .celsius)
            }
            if let celsiusUpper = alertService.upperCelsius(for: ruuviTag) {
                viewModel.temperatureUpperBound.value = Temperature(Double(celsiusUpper), unit: .celsius)
            }
        }
        viewModel.temperatureAlertMutedTill.value = alertService.mutedTill(type: temperature, for: ruuviTag)
    }

    private func sync(humidity: AlertType, ruuviTag: RuuviTagSensor) {
        if case .humidity(let lower, let upper) = alertService.alert(for: ruuviTag, of: humidity) {
            viewModel.isHumidityAlertOn.value = true
            viewModel.humidityLowerBound.value = lower.converted(to: .absolute)
            viewModel.humidityUpperBound.value = upper.converted(to: .absolute)
        } else {
            viewModel.isHumidityAlertOn.value = false
            if let humidityLower = alertService.lowerHumidity(for: ruuviTag) {
                viewModel.humidityLowerBound.value = humidityLower
            }
            if let humidityUpper = alertService.upperHumidity(for: ruuviTag) {
                viewModel.humidityUpperBound.value = humidityUpper
            }
        }
        viewModel.humidityAlertMutedTill.value = alertService.mutedTill(type: humidity, for: ruuviTag)
    }

    private func sync(relativeHumidity: AlertType, ruuviTag: RuuviTagSensor) {
        if case .relativeHumidity(let lower, let upper) = alertService.alert(for: ruuviTag, of: relativeHumidity) {
            viewModel.isRelativeHumidityAlertOn.value = true
            // must multiply by 100 because it is fraction of one
            viewModel.relativeHumidityLowerBound.value = lower * 100.0
            viewModel.relativeHumidityUpperBound.value = upper * 100.0
        } else {
            viewModel.isRelativeHumidityAlertOn.value = false
            if let humidityLower = alertService.lowerRelativeHumidity(for: ruuviTag) {
                // must multiply by 100 because it is fraction of one
                viewModel.relativeHumidityLowerBound.value = humidityLower * 100.0
            }
            if let humidityUpper = alertService.upperRelativeHumidity(for: ruuviTag) {
                // must multiply by 100 because it is fraction of one
                viewModel.relativeHumidityUpperBound.value = humidityUpper * 100.0
            }
        }
        viewModel.relativeHumidityAlertMutedTill.value = alertService.mutedTill(type: relativeHumidity, for: ruuviTag)
    }

    private func sync(pressure: AlertType, ruuviTag: RuuviTagSensor) {
        if case .pressure(let lower, let upper) = alertService.alert(for: ruuviTag, of: pressure) {
            viewModel.isPressureAlertOn.value = true
            viewModel.pressureLowerBound.value = Pressure(Double(lower), unit: .hectopascals)
            viewModel.pressureUpperBound.value =  Pressure(Double(upper), unit: .hectopascals)
        } else {
            viewModel.isPressureAlertOn.value = false
            if let pressureLowerBound = alertService.lowerPressure(for: ruuviTag) {
                viewModel.pressureLowerBound.value = Pressure(Double(pressureLowerBound), unit: .hectopascals)
            }
            if let pressureUpperBound = alertService.upperPressure(for: ruuviTag) {
                viewModel.pressureUpperBound.value = Pressure(Double(pressureUpperBound), unit: .hectopascals)
            }
        }
        viewModel.pressureAlertMutedTill.value = alertService.mutedTill(type: pressure, for: ruuviTag)
    }

    private func sync(signal: AlertType, ruuviTag: RuuviTagSensor) {
        if case .signal(let lower, let upper) = alertService.alert(for: ruuviTag, of: signal) {
            viewModel.isSignalAlertOn.value = true
            viewModel.signalLowerBound.value = Double(lower)
            viewModel.signalUpperBound.value =  Double(upper)
        } else {
            viewModel.isSignalAlertOn.value = false
            if let signalLowerBound = alertService.lowerSignal(for: ruuviTag) {
                viewModel.signalLowerBound.value = signalLowerBound
            }
            if let signalUpperBound = alertService.upperSignal(for: ruuviTag) {
                viewModel.signalUpperBound.value = signalUpperBound
            }
        }
        viewModel.signalAlertMutedTill.value =
            alertService.mutedTill(type: signal, for: ruuviTag)
    }

    private func sync(connection: AlertType, ruuviTag: RuuviTagSensor) {
        if case .connection = alertService.alert(for: ruuviTag, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
        viewModel.connectionAlertMutedTill.value = alertService.mutedTill(type: connection, for: ruuviTag)
    }

    private func sync(movement: AlertType, ruuviTag: RuuviTagSensor) {
        if case .movement = alertService.alert(for: ruuviTag, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
        viewModel.movementAlertMutedTill.value = alertService.mutedTill(type: movement, for: ruuviTag)
    }

    private func startSubscribeToBackgroundUploadProgressChanges() {
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    if (sSelf.ruuviTag.luid?.value != nil && sSelf.ruuviTag.luid?.value == luid?.value)
                        || (sSelf.ruuviTag.macId?.value != nil && sSelf.ruuviTag.macId?.value == macId?.value) {
                        sSelf.ruuviSensorPropertiesService.getImage(for: sSelf.ruuviTag)
                            .on(success: { [weak sSelf] image in
                                sSelf?.viewModel.background.value = image
                            }, failure: { [weak sSelf] error in
                                sSelf?.errorPresenter.present(error: error)
                            })
                    }
                }
            }
    }

    private func startObservingRuuviTag() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] (change) in
            switch change {
            case .insert(let sensor):
                if (sensor.luid?.any != nil && sensor.luid?.any == self?.ruuviTag.luid?.any)
                    || (sensor.macId?.any != nil && sensor.macId?.any == self?.ruuviTag.macId?.any) {
                    self?.ruuviTag = sensor
                }
            case .update(let sensor):
                if (sensor.luid?.any != nil && sensor.luid?.any == self?.ruuviTag.luid?.any)
                    || (sensor.macId?.any != nil && sensor.macId?.any == self?.ruuviTag.macId?.any) {
                    self?.ruuviTag = sensor
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                return
            }
        }
    }

    private func startObservingRuuviTagSensor(ruuviTag: RuuviTagSensor) {
        ruuviTagSensorRecordToken?.invalidate()
        ruuviTagSensorRecordToken = ruuviReactor.observeLatest(ruuviTag, {
            [weak self] (changes) in
            switch changes {
            case .update(let record):
                if let lastRecord = record {
                    self?.lastMeasurement = lastRecord
                    self?.viewModel.updateRecord(lastRecord)
                    self?.processAlerts()
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            default:
                break
            }
        })
    }
    private func startScanningRuuviTag() {
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        guard let luid = ruuviTag.luid else {
            return
        }
        let skip = settings.cloudModeEnabled && ruuviTag.isCloud
        guard !skip else {
            return
        }
        advertisementToken = foreground.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.handleMeasurementPoint(tag: tag, luid: luid, source: .advertisement)
            }
        })

        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] (_, device) in
            if let tag = device.ruuvi?.tag {
                self?.handleMeasurementPoint(tag: tag, luid: luid, source: .heartbeat)
            }
        })
    }

    private func handleMeasurementPoint(tag: RuuviTag,
                                        luid: LocalIdentifier,
                                        source: RuuviTagSensorRecordSource) {
        // RuuviTag with data format 5 or above has the measurements sequence number
        if tag.version >= 5 {
            if previousAdvertisementSequence != nil {
                if tag.measurementSequenceNumber != previousAdvertisementSequence {
                    sync(device: tag, luid: luid, source: source)
                    previousAdvertisementSequence = nil
                }
            } else {
                previousAdvertisementSequence = tag.measurementSequenceNumber
            }
        } else {
            sync(device: tag, luid: luid, source: source)
        }
    }

    private func sync(device: RuuviTag,
                      luid: LocalIdentifier,
                      source: RuuviTagSensorRecordSource) {
        let record = RuuviTagSensorRecordStruct(
            luid: device.luid,
            date: device.date,
            source: source,
            macId: device.mac?.mac,
            rssi: device.rssi,
            temperature: device.temperature,
            humidity: device.humidity,
            pressure: device.pressure,
            acceleration: device.acceleration,
            voltage: device.voltage,
            movementCounter: device.movementCounter,
            measurementSequenceNumber: device.measurementSequenceNumber,
            txPower: device.txPower,
            temperatureOffset: sensorSettings?.temperatureOffset ?? 0.0,
            humidityOffset: sensorSettings?.humidityOffset ?? 0.0,
            pressureOffset: sensorSettings?.pressureOffset ?? 0.0
        ).with(sensorSettings: sensorSettings)
        if viewModel.version.value != device.version {
            viewModel.version.value = device.version
        }

        // Some important notes:
        // FW v2.5.9 DF3 and DF5 tags always returns connectable 'false' and source is always advertisement.
        // FW v3+ tags returns connectable 'true' in advertisement source when not connected.
        // FW v3+ tags returns connectable 'false' in advertisement source when connected.
        // FW v3+ tags returns connectable 'true' in heartbeat source when connected.

        // Known Issue: If same tag is attempted to be connected to two different device at the same
        // Or toggling the connection in both device simlataneously for the same tag the 'keep connection'
        // section might get hidded for a split second after turning on the toggle.

        // If the firmware version returns nil that means it's an old firmware less than v3.
        // This refers to the fact that those tags do not have the capabilities for the connection
        if ruuviTag.firmwareVersion != nil {
            if device.isConnected {
                viewModel.isConnected.value = device.isConnected
                if source == .heartbeat {
                    viewModel.isConnectable.value = device.isConnectable
                } else {
                    viewModel.isConnectable.value = device.isConnected
                }
            } else {
                viewModel.isConnectable.value = device.isConnectable
            }
        } else {
            guard !device.isConnected else {
                return
            }
            viewModel.isConnected.value = false
            viewModel.isConnectable.value = false
        }

        if let mac = device.mac {
            viewModel.mac.value = mac
        }
        if let rssi = device.rssi {
            viewModel.rssi.value = rssi
        }

        viewModel.humidityOffsetCorrectionVisible.value = !(device.humidity == nil)
        viewModel.pressureOffsetCorrectionVisible.value = !(device.pressure == nil)

        viewModel.updateRecord(record)
        reloadMutedTill()
    }

    private func bindViewModel(to ruuviTag: RuuviTagSensor) {
        if let luid = ruuviTag.luid {
            bind(viewModel.keepConnection, fire: false) { [weak self] observer, keepConnection in
                observer.connectionPersistence.setKeepConnection(keepConnection.bound, for: luid)
                // Toggle the background scanning if any tag is asked to pair.
                if keepConnection.bound {
                    self?.settings.saveHeartbeats = true
                }
            }
        }

        bindTemperatureAlert(for: ruuviTag)
        bindRhAlert(for: ruuviTag)
        bindHumidityAlert(for: ruuviTag)
        bindPressureAlert(for: ruuviTag)
        bindRSSIAlert(for: ruuviTag)
        bindConnectionAlert(for: ruuviTag)
        bindMovementAlert(for: ruuviTag)

        bindOffsetCorrection()
    }

    private func bindRhAlert(for ruuviTag: RuuviTagSensor) {
        let rhLower = viewModel.relativeHumidityLowerBound
        let rhUpper = viewModel.relativeHumidityUpperBound
        bind(viewModel.isRelativeHumidityAlertOn, fire: false) {
            [weak self,
             weak rhLower,
             weak rhUpper] observer, isOn in
            if let l = rhLower?.value, let u = rhUpper?.value {
                // must divide by 100 because it's fraction of one
                let type: AlertType = .relativeHumidity(
                    lower: l / 100.0,
                    upper: u / 100.0
                )
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, ruuviTag: ruuviTag)
                        self?.processAlerts()
                    } else {
                        observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                    }
                    observer.alertService.unmute(type: type, for: ruuviTag)
                }
            }
        }

        let lowRhDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.relativeHumidityLowerBound, fire: false) {
            [weak self] observer, lower in
            if let l = lower {
                lowRhDebouncer.run {
                    // must divide by 100 to get fraction of one as per contract
                    observer.alertService.setLower(relativeHumidity: l / 100.0, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }
        let upperRhDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.relativeHumidityUpperBound, fire: false) {
            [weak self] observer, upper in
            if let u = upper {
                upperRhDebouncer.run {
                    // must divide by 100 to get fraction of one as per contract
                    observer.alertService.setUpper(relativeHumidity: u / 100.0, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        bind(viewModel.relativeHumidityAlertDescription, fire: false) {observer, relativeHumidityAlertDescription in
            observer.alertService.setRelativeHumidity(description: relativeHumidityAlertDescription, ruuviTag: ruuviTag)
        }
    }

    private func bindRSSIAlert(for ruuviTag: RuuviTagSensor) {
        let signalLower = viewModel.signalLowerBound
        let signalUpper = viewModel.signalUpperBound
        bind(viewModel.isSignalAlertOn, fire: false) {
            [weak self,
             weak signalLower,
             weak signalUpper] observer, isOn in
            if let l = signalLower?.value, let u = signalUpper?.value {
                // must divide by 100 because it's fraction of one
                let type: AlertType = .signal(
                    lower: l,
                    upper: u
                )
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, ruuviTag: ruuviTag)
                        self?.processAlerts()
                    } else {
                        observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                    }
                    observer.alertService.unmute(type: type, for: ruuviTag)
                }
            }
        }

        let lowSignalDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.signalLowerBound, fire: false) {
            [weak self] observer, lower in
            if let l = lower {
                lowSignalDebouncer.run {
                    observer.alertService.setLower(signal: l, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        let upperSignalDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.signalUpperBound, fire: false) {
            [weak self] observer, upper in
            if let u = upper {
                upperSignalDebouncer.run {
                    observer.alertService.setUpper(signal: u, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        bind(viewModel.signalAlertDescription, fire: false) {
            observer, signalAlertDescription in
            observer.alertService.setSignal(
                description: signalAlertDescription, ruuviTag: ruuviTag)
        }
    }

    private func bindTemperatureAlert(for ruuviTag: RuuviTagSensor) {
        let temperatureLower = viewModel.temperatureLowerBound
        let temperatureUpper = viewModel.temperatureUpperBound
        bind(viewModel.isTemperatureAlertOn, fire: false) {
            [weak self,
             weak temperatureLower,
             weak temperatureUpper] observer, isOn in
            if let l = temperatureLower?.value?.converted(to: .celsius).value,
               let u = temperatureUpper?.value?.converted(to: .celsius).value {
                let type: AlertType = .temperature(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, ruuviTag: ruuviTag)
                    } else {
                        observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                    }
                    observer.alertService.unmute(type: type, for: ruuviTag)
                }
                self?.processAlerts()
            }
        }

        let lowTemperatureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.temperatureLowerBound, fire: false) {
            [weak self] observer, lower in
            if let l = lower?.converted(to: .celsius).value {
                lowTemperatureDebouncer.run {
                    observer.alertService.setLower(celsius: l, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }
        let upperTemperatureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.temperatureUpperBound, fire: false) {
            [weak self] observer, upper in
            if let u = upper?.converted(to: .celsius).value {
                upperTemperatureDebouncer.run {
                    observer.alertService.setUpper(celsius: u, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        bind(viewModel.temperatureAlertDescription, fire: false) {
            observer, temperatureAlertDescription in
            observer.alertService.setTemperature(
                description: temperatureAlertDescription, ruuviTag: ruuviTag)
        }
    }

    private func bindHumidityAlert(for ruuviTag: RuuviTagSensor) {
        let humidityLower = viewModel.humidityLowerBound
        let humidityUpper = viewModel.humidityUpperBound
        bind(viewModel.isHumidityAlertOn, fire: false) {
            [weak self,
             weak humidityLower,
             weak humidityUpper] observer, isOn in
            if let l = humidityLower?.value,
               let u = humidityUpper?.value {
                let type: AlertType = .humidity(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, ruuviTag: ruuviTag)
                        self?.processAlerts()
                    } else {
                        observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                    }
                    observer.alertService.unmute(type: type, for: ruuviTag)
                }
            }
        }

        let lowHumidityDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.humidityLowerBound, fire: false) {
            [weak self] observer, lower in
            lowHumidityDebouncer.run {
                observer.alertService.setLower(humidity: lower, for: ruuviTag)
                self?.processAlerts()
            }
        }
        let upperHumidityDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.humidityUpperBound, fire: false) {
            [weak self] observer, upper in
            upperHumidityDebouncer.run {
                observer.alertService.setUpper(humidity: upper, for: ruuviTag)
                self?.processAlerts()
            }
        }
        bind(viewModel.humidityAlertDescription, fire: false) {
            observer, humidityAlertDescription in
            observer.alertService.setHumidity(
                description: humidityAlertDescription, for: ruuviTag)
        }
    }

    private func bindPressureAlert(for ruuviTag: RuuviTagSensor) {
        let pressureLower = viewModel.pressureLowerBound
        let pressureUpper = viewModel.pressureUpperBound
        bind(viewModel.isPressureAlertOn, fire: false) {
            [weak self,
             weak pressureLower,
             weak pressureUpper] observer, isOn in
            if let l = pressureLower?.value?.converted(to: .hectopascals).value,
               let u = pressureUpper?.value?.converted(to: .hectopascals).value {
                let type: AlertType = .pressure(lower: l, upper: u)
                let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
                if currentState != isOn.bound {
                    if isOn.bound {
                        observer.alertService.register(type: type, ruuviTag: ruuviTag)
                        self?.processAlerts()
                    } else {
                        observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                    }
                    observer.alertService.unmute(type: type, for: ruuviTag)
                }
            }
        }

        let lowPressureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.pressureLowerBound, fire: false) {
            [weak self] observer, lower in
            if let l = lower?.converted(to: .hectopascals).value {
                lowPressureDebouncer.run {
                    observer.alertService.setLower(pressure: l, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        let upperPressureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        bind(viewModel.pressureUpperBound, fire: false) {
            [weak self] observer, upper in
            if let u = upper?.converted(to: .hectopascals).value {
                upperPressureDebouncer.run {
                    observer.alertService.setUpper(pressure: u, ruuviTag: ruuviTag)
                    self?.processAlerts()
                }
            }
        }

        bind(viewModel.pressureAlertDescription, fire: false) {
            observer, pressureAlertDescription in
            observer.alertService.setPressure(
                description: pressureAlertDescription, ruuviTag: ruuviTag)
        }
    }

    private func bindConnectionAlert(for ruuviTag: RuuviTagSensor) {
        bind(viewModel.isConnectionAlertOn, fire: false) { observer, isOn in
            let type: AlertType = .connection
            let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn.bound {
                if isOn.bound {
                    observer.alertService.register(type: type, ruuviTag: ruuviTag)
                } else {
                    observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                observer.alertService.unmute(type: type, for: ruuviTag)
            }
        }

        bind(viewModel.connectionAlertDescription, fire: false) {
            observer, connectionAlertDescription in
            observer.alertService.setConnection(
                description: connectionAlertDescription, for: ruuviTag)
        }
    }

    private func bindMovementAlert(for ruuviTag: RuuviTagSensor) {
        let movement = viewModel.movementCounter
        bind(viewModel.isMovementAlertOn, fire: false) {
            [weak self,
             weak movement] observer, isOn in
            let last = movement?.value ?? 0
            let type: AlertType = .movement(last: last)
            let currentState = observer.alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn.bound {
                if isOn.bound {
                    observer.alertService.register(type: type, ruuviTag: ruuviTag)
                    self?.processAlerts()
                } else {
                    observer.alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                observer.alertService.unmute(type: type, for: ruuviTag)
            }
        }
        bind(viewModel.movementAlertDescription, fire: false) {
            observer, movementAlertDescription in
            observer.alertService.setMovement(
                description: movementAlertDescription,
                ruuviTag: ruuviTag
            )
        }
    }

    private func bindOffsetCorrection() {
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset
    }

    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.viewModel.humidityUnit.value = self?.settings.humidityUnit
                         })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.viewModel.pressureUnit.value = self?.settings.pressureUnit
                         })
    }

    private func startObservingConnectionStatus() {
        connectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                               uuid == self?.ruuviTag.luid?.value {
                                self?.viewModel.isConnected.value = true
                            }
                         })

        disconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                if let userInfo = notification.userInfo,
                   let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                   uuid == self?.ruuviTag.luid?.value {
                    self?.viewModel.isConnected.value = false
                }
            })
    }

    private func startObservingApplicationState() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                            self?.checkPushNotificationsStatus()
                         })
    }

    private func checkPushNotificationsStatus() {
        pushNotificationsManager.getRemoteNotificationsAuthorizationStatus { [weak self] (status) in
            switch status {
            case .notDetermined:
                self?.pushNotificationsManager.registerForRemoteNotifications()
            case .authorized:
                self?.viewModel.isPushNotificationsEnabled.value = true
            case .denied:
                self?.viewModel.isPushNotificationsEnabled.value = false
            }
        }
    }

    private func checkLastSensorSettings() {
        ruuviStorage.readSensorSettings(self.ruuviTag).on { settings in
            self.sensorSettings = settings
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo {
                               if let physicalSensor
                                    = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                                  physicalSensor.id == self?.viewModel.uuid.value,
                                   let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                                    self?.updateIsOnState(of: type, for: physicalSensor.id)
                                    self?.updateMutedTill(of: type, for: physicalSensor.id)
                                }
                                if let virtualSensor
                                    = userInfo[RuuviServiceAlertDidChangeKey.virtualSensor] as? VirtualSensor,
                                   virtualSensor.id == self?.viewModel.uuid.value,
                                    let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                                    self?.updateIsOnState(of: type, for: virtualSensor.id)
                                     self?.updateMutedTill(of: type, for: virtualSensor.id)
                                 }
                            }
                         })
    }

    private func reloadMutedTill() {
        if let mutedTill = viewModel.temperatureAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.temperatureAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.humidityAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.humidityAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.pressureAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.pressureAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.signalAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.signalAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.connectionAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.connectionAlertMutedTill.value = nil
        }

        if let mutedTill = viewModel.movementAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.movementAlertMutedTill.value = nil
        }
    }

    private func updateMutedTill(of type: AlertType, for uuid: String) {
        var observable: Observable<Date?>
        switch type {
        case .temperature:
            observable = viewModel.temperatureAlertMutedTill
        case .relativeHumidity:
            observable = viewModel.relativeHumidityAlertMutedTill
        case .humidity:
            observable = viewModel.humidityAlertMutedTill
        case .pressure:
            observable = viewModel.pressureAlertMutedTill
        case .signal:
            observable = viewModel.signalAlertMutedTill
        case .connection:
            observable = viewModel.connectionAlertMutedTill
        case .movement:
            observable = viewModel.movementAlertMutedTill
        }

        let date = alertService.mutedTill(type: type, for: uuid)
        if date != observable.value {
            observable.value = date
        }
    }

    private func updateIsOnState(of type: AlertType, for uuid: String) {
        var observable: Observable<Bool?>
        switch type {
        case .temperature:
            observable = viewModel.isTemperatureAlertOn
        case .relativeHumidity:
            observable = viewModel.isRelativeHumidityAlertOn
        case .humidity:
            observable = viewModel.isHumidityAlertOn
        case .pressure:
            observable = viewModel.isPressureAlertOn
        case .signal:
            observable = viewModel.isSignalAlertOn
        case .connection:
            observable = viewModel.isConnectionAlertOn
        case .movement:
            observable = viewModel.isMovementAlertOn
        }

        let isOn = alertService.isOn(type: type, for: uuid)
        if isOn != observable.value {
            observable.value = isOn
            processAlerts()
        }
    }

    private func processAlerts() {
        guard let lastMeasurement = lastMeasurement else {
            return
        }

        if ruuviTag.isCloud && settings.cloudModeEnabled,
            let macId = ruuviTag.macId {
            alertHandler.processNetwork(record: lastMeasurement,
                                        trigger: false,
                                        for: macId)
        } else {
            if ruuviTag.luid?.value != nil {
                alertHandler.process(record: lastMeasurement,
                                     trigger: false)
            } else {
                guard let macId = ruuviTag.macId else {
                    return
                }
                alertHandler.processNetwork(record: lastMeasurement,
                                            trigger: false,
                                            for: macId)
            }
        }
    }

    /// Sets up a 10 seconds timer to attempt pairing to a Ruuvi Sensor via Bluetooth.
    private func setupTimeoutTimerForKeepConnection() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] (_) in
            guard let self = self else { return }
            self.invalidateTimer()
            if let isConnected = self.viewModel.isConnected.value,
               !isConnected {
                self.viewModel.keepConnection.value = false
                self.view.resetKeepConnectionSwitch()
                self.view.showKeepConnectionTimeoutDialog()
            }
        })
    }

    /// Invalidates the running timer
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

}

// MARK: - RuuviNotifierObserver
extension TagSettingsPresenter: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        // No op here.
    }

    func ruuvi(notifier: RuuviNotifier,
               alertType: AlertType,
               isTriggered: Bool,
               for uuid: String) {

        if ruuviTag.luid?.value == uuid || ruuviTag.macId?.value == uuid {
            let isFireable = ruuviTag.isCloud || viewModel.isConnected.value ?? false
            switch alertType {
            case .temperature:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isTemperatureAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.temperatureAlertState.value = newValue
            case .relativeHumidity:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isRelativeHumidityAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.relativeHumidityAlertState.value = newValue
            case .pressure:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isPressureAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.pressureAlertState.value = newValue
            case .signal:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isSignalAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.signalAlertState.value = newValue
            case .connection:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isConnectionAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.connectionAlertState.value = newValue
            case .movement:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isMovementAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.movementAlertState.value = newValue
            default:
                break
            }
        }
    }
}

extension TagSettingsPresenter: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = exportFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
// swiftlint:enable file_length
