import BTKit
import Foundation
import Future
import RuuviLocal
// swiftlint:disable file_length cyclomatic_complexity
import RuuviLocalization
import RuuviOntology
import RuuviReactor
import RuuviService
import RuuviStorage
import UIKit
import RuuviCore
import RuuviDaemon
import RuuviNotifier
import RuuviPool
import RuuviPresenters
import RuuviUser
import RuuviCloud

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

    private static let lowUpperDebounceDelay: TimeInterval = 0.3

    private var ruuviTag: RuuviTagSensor! {
        didSet {
            syncTag()
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
    private var ruuviTagSensorOwnerCheckToken: NSObjectProtocol?
    private var advertisementToken: ObservationToken?
    private var heartbeatToken: ObservationToken?
    private var sensorSettingsToken: RuuviReactorToken?
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
            syncLastMeasurement()
            syncOffsetCorrection()
        }
    }

    private var firmwareUpdateDialogShown: Bool = false

    private var timer: Timer?

    deinit {
        lastMeasurement = nil
        mutedTillTimer?.invalidate()
        ruuviTagToken?.invalidate()
        ruuviTagSensorRecordToken?.invalidate()
        ruuviTagSensorOwnerCheckToken?.invalidate()
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        sensorSettingsToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        connectToken?.invalidate()
        disconnectToken?.invalidate()
        appDidBecomeActiveToken?.invalidate()
        alertDidChangeToken?.invalidate()
        backgroundToken?.invalidate()
        timer?.invalidate()
        RuuviCloudRequestStateObserverManager
            .shared
            .stopObserving(for: ruuviTag.macId?.value)
        NotificationCenter.default.removeObserver(self)
    }

    func configure(
        ruuviTag: RuuviTagSensor,
        latestMeasurement: RuuviTagSensorRecord?,
        sensorSettings: SensorSettings?
    ) {
        // Create the ViewModel
        let tagViewModel = TagSettingsViewModel()

        // Assign initial values to the ViewModel
        tagViewModel.isAuthorized.value = ruuviUser.isAuthorized
        tagViewModel.hideSwitchStatusLabel.value = !settings.showSwitchStatusLabel
        tagViewModel.rssi.value = latestMeasurement?.rssi
        tagViewModel.latestMeasurement.value = latestMeasurement
        tagViewModel.temperatureUnit.value = settings.temperatureUnit
        tagViewModel.humidityUnit.value = settings.humidityUnit
        tagViewModel.pressureUnit.value = settings.pressureUnit

        // Assign to the presenter property
        self.viewModel = tagViewModel

        // Assign ruuviTag and other properties
        self.ruuviTag = ruuviTag
        self.lastMeasurement = latestMeasurement
        self.sensorSettings = sensorSettings ?? emptySensorSettings()

        // Sync data into the ViewModel
        syncTag()
        syncUnits()
        syncAllAlerts()
        syncMaxShareCount()
        syncLastMeasurement()
        syncOffsetCorrection()

        // Bind ViewModel to View after syncing all data
        view.viewModel = viewModel
        view.dashboardSortingType =
            settings.dashboardSensorOrder.count == 0 ? .alphabetical : .manual

        // Bind ViewModel to ruuviTag and start observing
        bindViewModel()
        startObservingRuuviTag()
        startScanningRuuviTag()
        startObservingRuuviTagSensor(ruuviTag: ruuviTag)
        startObservingSettingsChanges()
        startObservingSensorSettings()
        startObservingConnectionStatus()
        startObservingApplicationState()
        startObservingAlertChanges()
        startObservingCloudRequestState()
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
        checkAndUpdateFirmwareVersion()
        startObservingRuuviTagOwnerCheckResponse()
    }

    private func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(handleAppEnterForgroundState),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(handleAppEnterBackgroundState),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
    }

    @objc private func handleAppEnterForgroundState() {
        syncAllAlerts()
        if let keep = viewModel.keepConnection.value,
           let connected = viewModel.isConnected.value {
            if keep, !connected {
                view.startKeepConnectionAnimatingDots()
            }
        }
    }

    @objc private func handleAppEnterBackgroundState() {
        if let keep = viewModel.keepConnection.value,
           let connected = viewModel.isConnected.value {
            if keep, !connected {
                view.stopKeepConnectionAnimatingDots()
            }
        }
    }

    func viewDidAskToDismiss() {
        output?.tagSettingsDidDismiss(module: self)
    }

    func viewDidConfirmClaimTag() {
        router.openOwner(ruuviTag: ruuviTag, mode: .claim)
    }

    func viewDidTriggerChangeBackground() {
        router.openBackgroundSelectionView(ruuviTag: ruuviTag)
    }

    func viewDidTriggerKeepConnection(isOn: Bool) {
        if settings.cloudModeEnabled, ruuviTag.isCloud {
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
        router.openSensorRemoval(ruuviTag: ruuviTag, output: self)
    }

    func viewDidChangeTag(name: String) {
        ruuviSensorPropertiesService.set(name: name, for: ruuviTag)
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
        guard let luid = ruuviTag.luid
        else {
            return
        }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view.showFirmwareUpdateDialog()
        }
    }

    func viewDidConfirmFirmwareUpdate() {
        guard ruuviTag.luid != nil
        else {
            return
        }
        router.openUpdateFirmware(ruuviTag: ruuviTag)
    }

    func viewDidChangeAlertState(for type: AlertType, isOn: Bool) {
        switch type {
        case .temperature:
            setTemperatureAlertState(isOn: isOn)
        case .humidity:
            break
        case .relativeHumidity:
            setRHAlertState(isOn: isOn)
        case .pressure:
            setPressureAlertState(isOn: isOn)
        case .signal:
            setSignalAlertState(isOn: isOn)
        case .carbonDioxide:
            setCarbonDioxideAlertState(isOn: isOn)
        case .pMatter1:
            setPMatter1AlertState(isOn: isOn)
        case .pMatter2_5:
            setPMatter2_5AlertState(isOn: isOn)
        case .pMatter4:
            setPMatter4AlertState(isOn: isOn)
        case .pMatter10:
            setPMatter10AlertState(isOn: isOn)
        case .voc:
            setVOCAlertState(isOn: isOn)
        case .nox:
            setNOXAlertState(isOn: isOn)
        case .sound:
            setSoundAlertState(isOn: isOn)
        case .luminosity:
            setLuminosityAlertState(isOn: isOn)
        case .connection:
            setConnectionAlertState(isOn: isOn)
        case .cloudConnection:
            setCloudConnectionAlertState(isOn: isOn)
        case .movement:
            setMovementAlertState(isOn: isOn)
        }
    }

    func viewDidChangeAlertLowerBound(for type: AlertType, lower: CGFloat) {
        switch type {
        case .temperature:
            setTemperatureAlertLowerBound(lower: lower)
        case .relativeHumidity:
            setRHAlertLowerBound(lower: lower)
        case .pressure:
            setPressureAlertLowerBound(lower: lower)
        case .signal:
            setSignalAlertLowerBound(lower: lower)
        case .carbonDioxide:
            setCarbonDioxideAlertLowerBound(lower: lower)
        case .pMatter1:
            setPMatter1AlertLowerBound(lower: lower)
        case .pMatter2_5:
            setPMatter2_5AlertLowerBound(lower: lower)
        case .pMatter4:
            setPMatter4AlertLowerBound(lower: lower)
        case .pMatter10:
            setPMatter10AlertLowerBound(lower: lower)
        case .voc:
            setVOCAlertLowerBound(lower: lower)
        case .nox:
            setNOXAlertLowerBound(lower: lower)
        case .sound:
            setSoundAlertLowerBound(lower: lower)
        case .luminosity:
            setLuminosityAlertLowerBound(lower: lower)
        default:
            break
        }
    }

    func viewDidChangeAlertUpperBound(for type: AlertType, upper: CGFloat) {
        switch type {
        case .temperature:
            setTemperatureAlertUpperBound(upper: upper)
        case .relativeHumidity:
            setRHAlertUpperBound(upper: upper)
        case .pressure:
            setPressureAlertUpperBound(upper: upper)
        case .signal:
            setSignalAlertUpperBound(upper: upper)
        case .carbonDioxide:
            setCarbonDioxideAlertUpperBound(upper: upper)
        case .pMatter1:
            setPMatter1AlertUpperBound(upper: upper)
        case .pMatter2_5:
            setPMatter2_5AlertUpperBound(upper: upper)
        case .pMatter4:
            setPMatter4AlertUpperBound(upper: upper)
        case .pMatter10:
            setPMatter10AlertUpperBound(upper: upper)
        case .voc:
            setVOCAlertUpperBound(upper: upper)
        case .nox:
            setNOXAlertUpperBound(upper: upper)
        case .sound:
            setSoundAlertUpperBound(upper: upper)
        case .luminosity:
            setLuminosityAlertUpperBound(upper: upper)
        default:
            break
        }
    }

    func viewDidChangeCloudConnectionAlertUnseenDuration(duration: Int) {
        setCloudConnectionAlertDelay(unseenDuration: duration)
    }

    func viewDidChangeAlertDescription(
        for type: AlertType,
        description: String?
    ) {
        switch type {
        case .temperature:
            setTemperatureAlertDescription(description: description)
        case .humidity:
            break
        case .relativeHumidity:
            setRHAlertDescription(description: description)
        case .pressure:
            setPressureAlertDescription(description: description)
        case .signal:
            setSignalAlertDescription(description: description)
        case .carbonDioxide:
            setCarbonDioxideAlertDescription(description: description)
        case .pMatter1:
            setPMatter1AlertDescription(description: description)
        case .pMatter2_5:
            setPMatter2_5AlertDescription(description: description)
        case .pMatter4:
            setPMatter4AlertDescription(description: description)
        case .pMatter10:
            setPMatter10AlertDescription(description: description)
        case .voc:
            setVOCAlertDescription(description: description)
        case .nox:
            setNOXAlertDescription(description: description)
        case .sound:
            setSoundAlertDescription(description: description)
        case .luminosity:
            setLuminosityAlertDescription(description: description)
        case .connection:
            setConnectionAlertDescription(description: description)
        case .cloudConnection:
            setCloudConnectionAlertDescription(description: description)
        case .movement:
            setMovementAlertDescription(description: description)
        }
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

    func viewDidTapOnOwner() {
        if viewModel.isClaimedTag.value == false {
            ruuviTagSensorOwnerCheckToken?.invalidate()
            ruuviTagSensorOwnerCheckToken = nil
            router.openOwner(ruuviTag: ruuviTag, mode: .claim)
        } else {
            if let isOwner = viewModel.isOwner.value, isOwner {
                router.openOwner(ruuviTag: ruuviTag, mode: .unclaim)
            } else {
                router.openContest(ruuviTag: ruuviTag)
            }
        }
    }
}

// MARK: - SensorRemovalModuleOutput

extension TagSettingsPresenter: SensorRemovalModuleOutput {
    func sensorRemovalDidRemoveTag(
        module: SensorRemovalModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            guard let sSelf = self else { return }
            sSelf.removeTagAndCleanup()
            sSelf.ruuviStorage.readAll().on(success: { [weak self] sensors in
                if sensors.count == 0 {
                    self?.router.dismissToRoot(completion: {
                        sSelf.output?.tagSettingsDidDeleteTag(
                            module: sSelf, ruuviTag: ruuviTag
                        )
                    })
                } else {
                    sSelf.output?.tagSettingsDidDeleteTag(
                        module: sSelf, ruuviTag: ruuviTag
                    )
                }
            })
        })
    }

    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {
        module.dismiss(completion: { [weak self] in
            guard let sSelf = self else { return }
            sSelf.output?.tagSettingsDidDismiss(module: sSelf)
        })
    }
}

// MARK: - Private

extension TagSettingsPresenter {
    private func startMutedTillTimer() {
        mutedTillTimer = Timer
            .scheduledTimer(
                withTimeInterval: 5,
                repeats: true
            ) { [weak self] timer in
                guard let sSelf = self else { timer.invalidate(); return }
                sSelf.reloadMutedTill()
            }
    }

    private func startListeningToRuuviTagsAlertStatus() {
        if ruuviTag.isCloud {
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
            observer.viewModel.isAlertsEnabled.value = isCl || isCo || observer.ruuviTag.serviceUUID != nil
        }

        let isConnected = viewModel.isConnected
        bind(viewModel.isCloudAlertsAvailable) { [weak isConnected] observer, isCloudAlertsAvailable in
            let isCl = isCloudAlertsAvailable ?? false
            let isCo = isConnected?.value ?? false
            observer.viewModel.isAlertsEnabled.value = isCl || isCo || observer.ruuviTag.serviceUUID != nil
            self.processAlerts()
        }
    }

    // Sets the view model properties related to the associated RuuviTag
    // swiftlint:disable:next function_body_length
    private func syncTag() {
        viewModel.serviceUUID.value = ruuviTag.serviceUUID

        ruuviSensorPropertiesService.getImage(for: ruuviTag)
            .on(success: { [weak self] image in
                self?.viewModel.background.value = image
            }, failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
        viewModel.isAuthorized.value = ruuviUser.isAuthorized

        viewModel.canShareTag.value =
            (ruuviTag.isOwner && ruuviTag.isClaimed) || ruuviTag.canShare
        viewModel.sharedTo.value = ruuviTag.sharedTo

        // Context:
        // The tag can be claimable only when -
        // 1: When - the tag is not claimed already, AND
        // 2: When - the tag macId is not Nil, AND
        // 3: When - there's no owner of the tag OR there's a owner of the tag but it's not the logged in user
        // Last one is for the scenario when a tag is added locally but claimed by other user
        let canBeClaimed = !ruuviTag.isClaimed && ruuviTag.macId != nil &&
            (ruuviTag.owner == nil || (ruuviTag.owner != nil && ruuviTag.isOwner))
        viewModel.canClaimTag.value = canBeClaimed
        viewModel.isClaimedTag.value = !canBeClaimed

        // Not set / Someone else / email of the one who shared the sensor with you / You
        if let owner = ruuviTag.owner {
            viewModel.owner.value = owner.lowercased()
        } else {
            viewModel.owner.value = RuuviLocalization.TagSettings.General.Owner.none
        }
        // Set isOwner value
        viewModel.isOwner.value = ruuviTag.isOwner
        viewModel.ownersPlan.value = ruuviTag.ownersPlan
        viewModel.isOwnersPlanProPlus.value =
            ruuviTag.ownersPlan?.lowercased() != "basic" &&
            ruuviTag.ownersPlan?.lowercased() != "free"

        viewModel.isCloudConnectionAlertsAvailable.value =
            ruuviUser.isAuthorized &&
            ruuviTag.isCloud &&
            viewModel.isOwnersPlanProPlus.value ?? false

        if ruuviTag.name == ruuviTag.luid?.value
            || ruuviTag.name == ruuviTag.macId?.value,
            !ruuviTag.isCloud {
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
    }

    /// Sets the view model properties related to the settings
    private func syncUnits() {
        viewModel.temperatureUnit.value = settings.temperatureUnit
        viewModel.humidityUnit.value = settings.humidityUnit
        viewModel.pressureUnit.value = settings.pressureUnit
    }

    /// Sets the view model properties related to the latest measurement
    private func syncLastMeasurement() {
        viewModel.humidityOffsetCorrectionVisible.value = !(lastMeasurement?.humidity == nil)
        viewModel.pressureOffsetCorrectionVisible.value = !(lastMeasurement?.pressure == nil)

        viewModel.temperature.value = lastMeasurement?.temperature
        viewModel.humidity.value = lastMeasurement?.humidity
        viewModel.movementCounter.value = lastMeasurement?.movementCounter
        viewModel.latestMeasurement.value = lastMeasurement
    }

    /// Sets the view model properties related to the offset corrections
    private func syncOffsetCorrection() {
        // reload offset correction
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset

        viewModel.humidityOffsetCorrectionVisible.value = !(lastMeasurement?.humidity == nil)
        viewModel.pressureOffsetCorrectionVisible.value = !(lastMeasurement?.pressure == nil)
    }

    private func syncMaxShareCount() {
        ruuviPool.readSensorSubscriptionSettings(
            ruuviTag
        ).on(success: { [weak self] subscription in
            if let maxShares = subscription?.maxSharesPerSensor {
                self?.view.maxShareCount = maxShares
            }
        })
    }

    /// Sets the view model properties related to provided alert type.
    private func syncAlerts(of type: AlertType) {
        switch type {
        case .temperature:
            sync(temperature: type, ruuviTag: ruuviTag)
        case .relativeHumidity:
            sync(relativeHumidity: type, ruuviTag: ruuviTag)
        case .humidity:
            break // We don't support it on iOS.
        case .pressure:
            sync(pressure: type, ruuviTag: ruuviTag)
        case .signal:
            sync(signal: type, ruuviTag: ruuviTag)
        case .carbonDioxide:
            sync(carbonDioxide: type, ruuviTag: ruuviTag)
        case .pMatter1:
            sync(pMatter1: type, ruuviTag: ruuviTag)
        case .pMatter2_5:
            sync(pMatter2_5: type, ruuviTag: ruuviTag)
        case .pMatter4:
            sync(pMatter4: type, ruuviTag: ruuviTag)
        case .pMatter10:
            sync(pMatter10: type, ruuviTag: ruuviTag)
        case .voc:
            sync(voc: type, ruuviTag: ruuviTag)
        case .nox:
            sync(nox: type, ruuviTag: ruuviTag)
        case .sound:
            sync(sound: type, ruuviTag: ruuviTag)
        case .luminosity:
            sync(luminosity: type, ruuviTag: ruuviTag)
        case .connection:
            sync(connection: type, ruuviTag: ruuviTag)
        case .cloudConnection:
            sync(cloudConnection: type, ruuviTag: ruuviTag)
        case .movement:
            sync(movement: type, ruuviTag: ruuviTag)
        }
    }

    /// Sets the view model properties related to all alert type.
    private func syncAllAlerts() {
        AlertType.allCases.forEach { type in
            syncAlerts(of: type)
        }
    }

    private func sync(temperature: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.temperatureAlertDescription.value = alertService.temperatureDescription(for: ruuviTag)
        if case let .temperature(lower, upper) = alertService.alert(for: ruuviTag, of: temperature) {
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

        // Set custom temp lower and upper bound and boolean manage the state
        viewModel.customTemperatureLowerBound.value = Temperature(
            settings.customTempAlertLowerBound,
            unit: .celsius
        )
        viewModel.customTemperatureUpperBound.value = Temperature(
            settings.customTempAlertUpperBound,
            unit: .celsius
        )
        viewModel.showCustomTempAlertBound.value = settings.showCustomTempAlertBound(
            for: ruuviTag.id
        )
    }

    private func sync(relativeHumidity: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.relativeHumidityAlertDescription.value = alertService.relativeHumidityDescription(
            for: ruuviTag
        )
        if case let .relativeHumidity(lower, upper) = alertService.alert(for: ruuviTag, of: relativeHumidity) {
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
        viewModel.pressureAlertDescription.value = alertService.pressureDescription(for: ruuviTag)
        if case let .pressure(lower, upper) = alertService.alert(for: ruuviTag, of: pressure) {
            viewModel.isPressureAlertOn.value = true
            viewModel.pressureLowerBound.value = Pressure(Double(lower), unit: .hectopascals)
            viewModel.pressureUpperBound.value = Pressure(Double(upper), unit: .hectopascals)
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
        viewModel.signalAlertDescription.value = alertService.signalDescription(for: ruuviTag)
        if case let .signal(lower, upper) = alertService.alert(for: ruuviTag, of: signal) {
            viewModel.isSignalAlertOn.value = true
            viewModel.signalLowerBound.value = Double(lower)
            viewModel.signalUpperBound.value = Double(upper)
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

    private func sync(carbonDioxide: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.carbonDioxideAlertDescription.value =
            alertService.carbonDioxideDescription(for: ruuviTag)
        if case let .carbonDioxide(lower, upper) = alertService.alert(for: ruuviTag, of: carbonDioxide) {
            viewModel.isCarbonDioxideAlertOn.value = true
            viewModel.carbonDioxideLowerBound.value = Double(lower)
            viewModel.carbonDioxideUpperBound.value = Double(upper)
        } else {
            viewModel.isCarbonDioxideAlertOn.value = false
            if let carbonDioxideLowerBound = alertService.lowerCarbonDioxide(for: ruuviTag) {
                viewModel.carbonDioxideLowerBound.value = carbonDioxideLowerBound
            }
            if let carbonDioxideUpperBound = alertService.upperCarbonDioxide(for: ruuviTag) {
                viewModel.carbonDioxideUpperBound.value = carbonDioxideUpperBound
            }
        }
        viewModel.carbonDioxideAlertMutedTill.value =
        alertService.mutedTill(type: carbonDioxide, for: ruuviTag)
    }

    private func sync(pMatter1: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.pMatter1AlertDescription.value = alertService.pm1Description(for: ruuviTag)
        if case let .pMatter1(lower, upper) = alertService
            .alert(for: ruuviTag, of: pMatter1) {
            viewModel.isPMatter1AlertOn.value = true
            viewModel.pMatter1LowerBound.value = Double(lower)
            viewModel.pMatter1UpperBound.value = Double(upper)
        } else {
            viewModel.isPMatter1AlertOn.value = false
            if let pMatter1LowerBound = alertService.lowerPM1(for: ruuviTag) {
                viewModel.pMatter1LowerBound.value = pMatter1LowerBound
            }
            if let pMatter1UpperBound = alertService.upperPM1(for: ruuviTag) {
                viewModel.pMatter1UpperBound.value = pMatter1UpperBound
            }
        }
        viewModel.pMatter1AlertMutedTill.value = alertService
            .mutedTill(type: pMatter1, for: ruuviTag)
    }

    private func sync(pMatter2_5: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.pMatter2_5AlertDescription.value = alertService.pm2_5Description(for: ruuviTag)
        if case let .pMatter2_5(lower, upper) = alertService
            .alert(for: ruuviTag, of: pMatter2_5) {
            viewModel.isPMatter2_5AlertOn.value = true
            viewModel.pMatter2_5LowerBound.value = Double(lower)
            viewModel.pMatter2_5UpperBound.value = Double(upper)
        } else {
            viewModel.isPMatter2_5AlertOn.value = false
            if let pMatter2_5LowerBound = alertService.lowerPM2_5(for: ruuviTag) {
                viewModel.pMatter2_5LowerBound.value = pMatter2_5LowerBound
            }
            if let pMatter2_5UpperBound = alertService.upperPM2_5(for: ruuviTag) {
                viewModel.pMatter2_5UpperBound.value = pMatter2_5UpperBound
            }
        }
        viewModel.pMatter2_5AlertMutedTill.value = alertService
            .mutedTill(type: pMatter2_5, for: ruuviTag)
    }

    private func sync(pMatter4: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.pMatter4AlertDescription.value = alertService.pm4Description(for: ruuviTag)
        if case let .pMatter4(lower, upper) = alertService
            .alert(for: ruuviTag, of: pMatter4) {
            viewModel.isPMatter4AlertOn.value = true
            viewModel.pMatter4LowerBound.value = Double(lower)
            viewModel.pMatter4UpperBound.value = Double(upper)
        } else {
            viewModel.isPMatter4AlertOn.value = false
            if let pMatter4LowerBound = alertService.lowerPM4(for: ruuviTag) {
                viewModel.pMatter4LowerBound.value = pMatter4LowerBound
            }
            if let pMatter4UpperBound = alertService.upperPM4(for: ruuviTag) {
                viewModel.pMatter4UpperBound.value = pMatter4UpperBound
            }
        }
        viewModel.pMatter4AlertMutedTill.value = alertService
            .mutedTill(type: pMatter4, for: ruuviTag)
    }

    private func sync(pMatter10: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.pMatter10AlertDescription.value = alertService.pm10Description(for: ruuviTag)
        if case let .pMatter10(lower, upper) = alertService
            .alert(for: ruuviTag, of: pMatter10) {
            viewModel.isPMatter10AlertOn.value = true
            viewModel.pMatter10LowerBound.value = Double(lower)
            viewModel.pMatter10UpperBound.value = Double(upper)
        } else {
            viewModel.isPMatter10AlertOn.value = false
            if let pMatter10LowerBound = alertService.lowerPM10(for: ruuviTag) {
                viewModel.pMatter10LowerBound.value = pMatter10LowerBound
            }
            if let pMatter10UpperBound = alertService.upperPM10(for: ruuviTag) {
                viewModel.pMatter10UpperBound.value = pMatter10UpperBound
            }
        }
        viewModel.pMatter10AlertMutedTill.value = alertService
            .mutedTill(type: pMatter10, for: ruuviTag)
    }

    private func sync(voc: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.vocAlertDescription.value = alertService.vocDescription(for: ruuviTag)
        if case let .voc(lower, upper) = alertService.alert(for: ruuviTag, of: voc) {
            viewModel.isVOCAlertOn.value = true
            viewModel.vocLowerBound.value = Double(lower)
            viewModel.vocUpperBound.value = Double(upper)
        } else {
            viewModel.isVOCAlertOn.value = false
            if let vocLowerBound = alertService.lowerVOC(for: ruuviTag) {
                viewModel.vocLowerBound.value = vocLowerBound
            }
            if let vocUpperBound = alertService.upperVOC(for: ruuviTag) {
                viewModel.vocUpperBound.value = vocUpperBound
            }
        }
        viewModel.vocAlertMutedTill.value = alertService
            .mutedTill(type: voc, for: ruuviTag)
    }

    private func sync(nox: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.noxAlertDescription.value = alertService.noxDescription(for: ruuviTag)
        if case let .nox(lower, upper) = alertService.alert(for: ruuviTag, of: nox) {
            viewModel.isNOXAlertOn.value = true
            viewModel.noxLowerBound.value = Double(lower)
            viewModel.noxUpperBound.value = Double(upper)
        } else {
            viewModel.isNOXAlertOn.value = false
            if let noxLowerBound = alertService.lowerNOX(for: ruuviTag) {
                viewModel.noxLowerBound.value = noxLowerBound
            }
            if let noxUpperBound = alertService.upperNOX(for: ruuviTag) {
                viewModel.noxUpperBound.value = noxUpperBound
            }
        }
        viewModel.noxAlertMutedTill.value = alertService
            .mutedTill(type: nox, for: ruuviTag)
    }

    private func sync(sound: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.soundAlertDescription.value = alertService.soundDescription(for: ruuviTag)
        if case let .sound(lower, upper) = alertService
            .alert(for: ruuviTag, of: sound) {
            viewModel.isSoundAlertOn.value = true
            viewModel.soundLowerBound.value = Double(lower)
            viewModel.soundUpperBound.value = Double(upper)
        } else {
            viewModel.isSoundAlertOn.value = false
            if let soundLowerBound = alertService.lowerSound(for: ruuviTag) {
                viewModel.soundLowerBound.value = soundLowerBound
            }
            if let soundUpperBound = alertService.upperSound(for: ruuviTag) {
                viewModel.soundUpperBound.value = soundUpperBound
            }
        }
        viewModel.soundAlertMutedTill.value = alertService
            .mutedTill(type: sound, for: ruuviTag)
    }

    private func sync(luminosity: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.luminosityAlertDescription.value = alertService.luminosityDescription(for: ruuviTag)
        if case let .luminosity(lower, upper) = alertService
            .alert(for: ruuviTag, of: luminosity) {
            viewModel.isLuminosityAlertOn.value = true
            viewModel.luminosityLowerBound.value = Double(lower)
            viewModel.luminosityUpperBound.value = Double(upper)
        } else {
            viewModel.isLuminosityAlertOn.value = false
            if let luminosityLowerBound = alertService.lowerLuminosity(
                for: ruuviTag
            ) {
                viewModel.luminosityLowerBound.value = luminosityLowerBound
            }
            if let luminosityUpperBound = alertService.upperLuminosity(
                for: ruuviTag
            ) {
                viewModel.luminosityUpperBound.value = luminosityUpperBound
            }
        }
        viewModel.luminosityAlertMutedTill.value = alertService
            .mutedTill(type: luminosity, for: ruuviTag)
    }

    private func sync(connection: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.connectionAlertDescription.value = alertService.connectionDescription(for: ruuviTag)
        if case .connection = alertService.alert(for: ruuviTag, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
        viewModel.connectionAlertMutedTill.value = alertService.mutedTill(type: connection, for: ruuviTag)
    }

    private func sync(cloudConnection: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.cloudConnectionAlertDescription.value =
            alertService.cloudConnectionDescription(for: ruuviTag)
        if case let .cloudConnection(unseenDuration) = alertService.alert(
            for: ruuviTag, of: cloudConnection
        ) {
            viewModel.isCloudConnectionAlertOn.value = true
            viewModel.cloudConnectionAlertUnseenDuration.value = unseenDuration
        } else {
            viewModel.isCloudConnectionAlertOn.value = false
            if let unseenDuration = alertService.cloudConnectionUnseenDuration(for: ruuviTag) {
                viewModel.cloudConnectionAlertUnseenDuration.value = unseenDuration
            } else {
                viewModel.cloudConnectionAlertUnseenDuration.value = 900
            }
        }
        viewModel.cloudConnectionAlertMutedTill.value =
            alertService.mutedTill(type: cloudConnection, for: ruuviTag)
    }

    private func sync(movement: AlertType, ruuviTag: RuuviTagSensor) {
        viewModel.movementAlertDescription.value = alertService.movementDescription(for: ruuviTag)
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
            .addObserver(
                forName: .BackgroundPersistenceDidChangeBackground,
                object: nil,
                queue: .main
            ) { [weak self] notification in

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
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            switch change {
            case let .insert(sensor):
                if (sensor.luid?.any != nil && sensor.luid?.any == self?.ruuviTag.luid?.any)
                    || (sensor.macId?.any != nil && sensor.macId?.any == self?.ruuviTag.macId?.any) {
                    self?.ruuviTag = sensor
                }
            case let .update(sensor):
                if (sensor.luid?.any != nil && sensor.luid?.any == self?.ruuviTag.luid?.any)
                    || (sensor.macId?.any != nil && sensor.macId?.any == self?.ruuviTag.macId?.any) {
                    self?.ruuviTag = sensor
                }
            case let .error(error):
                self?.errorPresenter.present(error: error)
            default:
                return
            }
        }
    }

    private func startObservingRuuviTagSensor(ruuviTag: RuuviTagSensor) {
        ruuviTagSensorRecordToken?.invalidate()
        ruuviTagSensorRecordToken = ruuviReactor.observeLatest(ruuviTag) {
            [weak self] changes in
            switch changes {
            case let .update(record):
                if let lastRecord = record {
                    self?.lastMeasurement = lastRecord
                    self?.viewModel.updateRecord(lastRecord)
                    self?.processAlerts()
                }
            case let .error(error):
                self?.errorPresenter.present(error: error)
            default:
                break
            }
        }
    }

    private func startObservingRuuviTagOwnerCheckResponse() {
        ruuviTagSensorOwnerCheckToken?.invalidate()
        ruuviTagSensorOwnerCheckToken = nil

        ruuviTagSensorOwnerCheckToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagOwnershipCheckDidEnd,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self,
                          let userInfo = notification.userInfo,
                          let hasOwner = userInfo[RuuviTagOwnershipCheckResultKey.hasOwner] as? Bool,
                          !hasOwner
                    else {
                        return
                    }
                    sSelf.view.showTagClaimDialog()
                }
            )
    }

    private func startScanningRuuviTag() {
        advertisementToken?.invalidate()
        heartbeatToken?.invalidate()
        guard let luid = ruuviTag.luid
        else {
            return
        }
        let skip = settings.cloudModeEnabled && ruuviTag.isCloud
        guard !skip
        else {
            return
        }
        advertisementToken = foreground.observe(self, uuid: luid.value, closure: { [weak self] _, device in
            if let tag = device.ruuvi?.tag, tag.luid?.value == luid.value {
                self?.handleMeasurementPoint(tag: tag, luid: luid, source: .advertisement)
            }
        })

        heartbeatToken = background.observe(self, uuid: luid.value, closure: { [weak self] _, device in
            if let tag = device.ruuvi?.tag, tag.luid?.value == luid.value {
                self?.handleMeasurementPoint(tag: tag, luid: luid, source: .heartbeat)
            }
        })
    }

    private func handleMeasurementPoint(
        tag: RuuviTag,
        luid: LocalIdentifier,
        source: RuuviTagSensorRecordSource
    ) {
        // Trigger firmware aler dialog for DF3 tags.
        if !firmwareUpdateDialogShown, tag.version < 5 {
            view.showFirmwareUpdateDialog()
            firmwareUpdateDialogShown = true
        }

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

    // swiftlint:disable:next function_body_length
    private func sync(
        device: RuuviTag,
        luid _: LocalIdentifier,
        source: RuuviTagSensorRecordSource
    ) {
        let record = RuuviTagSensorRecordStruct(
            luid: device.luid,
            date: device.date,
            source: source,
            macId: device.mac?.mac,
            rssi: device.rssi,
            version: device.version,
            temperature: device.temperature,
            humidity: device.humidity,
            pressure: device.pressure,
            acceleration: device.acceleration,
            voltage: device.voltage,
            movementCounter: device.movementCounter,
            measurementSequenceNumber: device.measurementSequenceNumber,
            txPower: device.txPower,
            pm1: device.pm1,
            pm2_5: device.pm2_5,
            pm4: device.pm4,
            pm10: device.pm10,
            co2: device.co2,
            voc: device.voc,
            nox: device.nox,
            luminance: device.luminance,
            dbaAvg: device.dbaAvg,
            dbaPeak: device.dbaPeak,
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
            guard !device.isConnected
            else {
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

        bindOffsetCorrection()
    }

    private func bindOffsetCorrection() {
        viewModel.temperatureOffsetCorrection.value = sensorSettings?.temperatureOffset
        viewModel.humidityOffsetCorrection.value = sensorSettings?.humidityOffset
        viewModel.pressureOffsetCorrection.value = sensorSettings?.pressureOffset
    }

    private func startObservingSensorSettings() {
        sensorSettingsToken?.invalidate()
        sensorSettingsToken = nil

        sensorSettingsToken = ruuviReactor.observe(ruuviTag) { [weak self] change in
            switch change {
            case let .insert(sensorSettings):
                self?.sensorSettings = sensorSettings
            case let .update(updateSensorSettings):
                self?.sensorSettings = updateSensorSettings
            case .delete:
                self?.sensorSettings = self?.emptySensorSettings()
            case let .initial(initialSensorSettings):
                self?.sensorSettings = initialSensorSettings.first
            case let .error(error):
                self?.errorPresenter.present(error: error)
            }
        }
    }

    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureUnitDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.viewModel.temperatureUnit.value = self?.settings.temperatureUnit
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.viewModel.humidityUnit.value = self?.settings.humidityUnit
                }
            )
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.viewModel.pressureUnit.value = self?.settings.pressureUnit
                }
            )
    }

    private func startObservingConnectionStatus() {
        connectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidConnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                       uuid == self?.ruuviTag.luid?.value {
                        self?.viewModel.isConnected.value = true
                    }
                }
            )

        disconnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidDisconnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                       uuid == self?.ruuviTag.luid?.value {
                        self?.viewModel.isConnected.value = false
                    }
                }
            )
    }

    private func startObservingApplicationState() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.checkPushNotificationsStatus()
                }
            )
    }

    private func checkPushNotificationsStatus() {
        pushNotificationsManager.getRemoteNotificationsAuthorizationStatus { [weak self] status in
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
        ruuviStorage.readSensorSettings(ruuviTag).on { settings in
            self.sensorSettings = settings
        }
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let isSyncing = self?.settings.isSyncing, isSyncing
                    else {
                        return
                    }
                    if let userInfo = notification.userInfo {
                        if let physicalSensor
                            = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                            physicalSensor.id == self?.viewModel.uuid.value,
                            let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                            self?.updateIsOnState(of: type, for: physicalSensor.id)
                            self?.updateMutedTill(of: type, for: physicalSensor.id)
                            self?.syncAlerts(of: type)
                        }
                    }
                }
            )
    }

    private func startObservingCloudRequestState() {
        guard let macId = ruuviTag.macId?.value else { return }
        // Stop if already observing
        RuuviCloudRequestStateObserverManager
            .shared
            .stopObserving(for: macId)

        RuuviCloudRequestStateObserverManager
            .shared
            .startObserving(for: macId) { [weak self] state in
                self?.presentActivityIndicator(with: state)
            }
    }

    private func reloadMutedTill() {
        if let mutedTill = viewModel.temperatureAlertMutedTill.value,
           mutedTill < Date() {
            viewModel.temperatureAlertMutedTill.value = nil
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
            return // We won't support it on iOS.
        case .pressure:
            observable = viewModel.pressureAlertMutedTill
        case .signal:
            observable = viewModel.signalAlertMutedTill
        case .carbonDioxide:
            observable = viewModel.carbonDioxideAlertMutedTill
        case .pMatter1:
            observable = viewModel.pMatter1AlertMutedTill
        case .pMatter2_5:
            observable = viewModel.pMatter2_5AlertMutedTill
        case .pMatter4:
            observable = viewModel.pMatter4AlertMutedTill
        case .pMatter10:
            observable = viewModel.pMatter10AlertMutedTill
        case .voc:
            observable = viewModel.vocAlertMutedTill
        case .nox:
            observable = viewModel.noxAlertMutedTill
        case .sound:
            observable = viewModel.soundAlertMutedTill
        case .luminosity:
            observable = viewModel.luminosityAlertMutedTill
        case .connection:
            observable = viewModel.connectionAlertMutedTill
        case .cloudConnection:
            observable = viewModel.cloudConnectionAlertMutedTill
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
            return // We don't support it on iOS.
        case .pressure:
            observable = viewModel.isPressureAlertOn
        case .signal:
            observable = viewModel.isSignalAlertOn
        case .carbonDioxide:
            observable = viewModel.isCarbonDioxideAlertOn
        case .pMatter1:
            observable = viewModel.isPMatter1AlertOn
        case .pMatter2_5:
            observable = viewModel.isPMatter2_5AlertOn
        case .pMatter4:
            observable = viewModel.isPMatter4AlertOn
        case .pMatter10:
            observable = viewModel.isPMatter10AlertOn
        case .voc:
            observable = viewModel.isVOCAlertOn
        case .nox:
            observable = viewModel.isNOXAlertOn
        case .sound:
            observable = viewModel.isSoundAlertOn
        case .luminosity:
            observable = viewModel.isLuminosityAlertOn
        case .connection:
            observable = viewModel.isConnectionAlertOn
        case .cloudConnection:
            observable = viewModel.isCloudConnectionAlertOn
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
        guard let lastMeasurement
        else {
            return
        }

        if ruuviTag.isCloud,
           let macId = ruuviTag.macId {
            alertHandler.processNetwork(
                record: lastMeasurement,
                trigger: false,
                for: macId
            )
        } else {
            if ruuviTag.luid?.value != nil {
                alertHandler.process(
                    record: lastMeasurement,
                    trigger: false
                )
            } else {
                guard let macId = ruuviTag.macId
                else {
                    return
                }
                alertHandler.processNetwork(
                    record: lastMeasurement,
                    trigger: false,
                    for: macId
                )
            }
        }
    }

    /// Sets up a 10 seconds timer to attempt pairing to a Ruuvi Sensor via Bluetooth.
    private func setupTimeoutTimerForKeepConnection() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true, block: { [weak self] _ in
            guard let self else { return }
            invalidateTimer()
            if let isConnected = viewModel.isConnected.value,
               !isConnected {
                viewModel.keepConnection.value = false
                view.resetKeepConnectionSwitch()
                view.showKeepConnectionTimeoutDialog()
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
    func ruuvi(notifier _: RuuviNotifier, isTriggered _: Bool, for _: String) {
        // No op here.
    }

    // swiftlint:disable:next function_body_length
    func ruuvi(
        notifier _: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        if ruuviTag.luid?.value == uuid || ruuviTag.macId?.value == uuid {
            let isFireable = ruuviTag.isCloud ||
                viewModel.isConnected.value ?? false ||
                viewModel.serviceUUID.value != nil
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
            case .carbonDioxide:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isCarbonDioxideAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.carbonDioxideAlertState.value = newValue
            case .pMatter1:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isPMatter1AlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.pMatter1AlertState.value = newValue
            case .pMatter2_5:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isPMatter2_5AlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.pMatter2_5AlertState.value = newValue
            case .pMatter4:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isPMatter4AlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.pMatter4AlertState.value = newValue
            case .pMatter10:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isPMatter10AlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.pMatter10AlertState.value = newValue
            case .voc:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isVOCAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.vocAlertState.value = newValue
            case .nox:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isNOXAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.noxAlertState.value = newValue
            case .sound:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isSoundAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.soundAlertState.value = newValue
            case .luminosity:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isLuminosityAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.luminosityAlertState.value = newValue
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
            case .cloudConnection:
                let isTriggered = isTriggered && isFireable && (viewModel.isAlertsEnabled.value ?? false)
                let isOn = viewModel.isCloudConnectionAlertOn.value ?? false
                let newValue: AlertState? = isTriggered ? .firing : (isOn ? .registered : .empty)
                viewModel.cloudConnectionAlertState.value = newValue
            default:
                break
            }
        }
    }
}

// MARK: - ALERT SETTERS

// MARK: - TEMPERATURE

extension TagSettingsPresenter {
    private func setTemperatureAlertState(isOn: Bool) {
        viewModel.isTemperatureAlertOn.value = isOn
        let temperatureLower = viewModel.temperatureLowerBound.value
        let temperatureUpper = viewModel.temperatureUpperBound.value

        if let l = temperatureLower?.converted(to: .celsius).value,
           let u = temperatureUpper?.converted(to: .celsius).value {
            let type: AlertType = .temperature(lower: l, upper: u)
            let currentState = alertService.isOn(
                type: type, for: ruuviTag
            )
            if currentState != isOn {
                if isOn {
                    alertService.register(
                        type: type, ruuviTag: ruuviTag
                    )
                } else {
                    alertService.unregister(
                        type: type, ruuviTag: ruuviTag
                    )
                }
                alertService.unmute(
                    type: type, for: ruuviTag
                )
            }
            processAlerts()
        }
    }

    private func setTemperatureAlertLowerBound(lower: CGFloat) {
        let lowTemperatureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        guard let tu = viewModel?.temperatureUnit.value else { return }
        let lowerBound = Temperature(Double(lower), unit: tu.unitTemperature)
        viewModel.temperatureLowerBound.value = lowerBound

        let temperatureUnit = viewModel?.temperatureUnit.value ?? .celsius
        let standardMinmimumBound = temperatureUnit.alertRange.lowerBound
        if lower < standardMinmimumBound {
            settings.setShowCustomTempAlertBound(for: ruuviTag.id)
            viewModel.showCustomTempAlertBound.value = true
        }

        guard let l = lowerBound?.converted(to: .celsius).value else { return }
        lowTemperatureDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(celsius: l, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setTemperatureAlertUpperBound(upper: CGFloat) {
        let upperTemperatureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        guard let tu = viewModel?.temperatureUnit.value else { return }
        let upperBound = Temperature(Double(upper), unit: tu.unitTemperature)
        viewModel.temperatureUpperBound.value = upperBound

        let temperatureUnit = viewModel?.temperatureUnit.value ?? .celsius
        let standardMaximumBound = temperatureUnit.alertRange.upperBound

        if upper > standardMaximumBound {
            settings.setShowCustomTempAlertBound(for: ruuviTag.id)
            viewModel.showCustomTempAlertBound.value = true
        }

        guard let u = upperBound?.converted(to: .celsius).value else { return }
        upperTemperatureDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(celsius: u, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setTemperatureAlertDescription(description: String?) {
        viewModel.temperatureAlertDescription.value = description
        alertService.setTemperature(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - RELATIVE HUMIDITY

extension TagSettingsPresenter {
    private func setRHAlertState(isOn: Bool) {
        viewModel.isRelativeHumidityAlertOn.value = isOn
        let rhLower = viewModel.relativeHumidityLowerBound.value
        let rhUpper = viewModel.relativeHumidityUpperBound.value

        if let l = rhLower, let u = rhUpper {
            // must divide by 100 because it's fraction of one
            let type: AlertType = .relativeHumidity(
                lower: l / 100.0,
                upper: u / 100.0
            )
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setRHAlertLowerBound(lower: CGFloat) {
        let upperRhDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.relativeHumidityLowerBound.value = lower

        upperRhDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                relativeHumidity: lower / 100.0,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setRHAlertUpperBound(upper: CGFloat) {
        let upperRhDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.relativeHumidityUpperBound.value = upper

        upperRhDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                relativeHumidity: upper / 100.0,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setRHAlertDescription(description: String?) {
        viewModel.relativeHumidityAlertDescription.value = description
        alertService.setRelativeHumidity(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - PRESSURE

extension TagSettingsPresenter {
    private func setPressureAlertState(isOn: Bool) {
        viewModel.isPressureAlertOn.value = isOn
        let pressureLower = viewModel.pressureLowerBound.value
        let pressureUpper = viewModel.pressureUpperBound.value

        if let l = pressureLower?.converted(to: .hectopascals).value,
           let u = pressureUpper?.converted(to: .hectopascals).value {
            let type: AlertType = .pressure(lower: l, upper: u)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setPressureAlertLowerBound(lower: CGFloat) {
        let lowPressureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        guard let pu = viewModel?.pressureUnit.value else { return }
        let lowerBound = Pressure(lower, unit: pu)
        viewModel.pressureLowerBound.value = lowerBound

        guard let l = lowerBound?.converted(
            to: .hectopascals
        ).value else { return }
        lowPressureDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                pressure: l, ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPressureAlertUpperBound(upper: CGFloat) {
        let upperPressureDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        guard let pu = viewModel?.pressureUnit.value else { return }
        let upperBound = Pressure(upper, unit: pu)
        viewModel.pressureUpperBound.value = upperBound

        guard let u = upperBound?.converted(to: .hectopascals).value else { return }
        upperPressureDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                pressure: u,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPressureAlertDescription(description: String?) {
        viewModel.pressureAlertDescription.value = description
        alertService.setPressure(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - SIGNAL

extension TagSettingsPresenter {
    private func setSignalAlertState(isOn: Bool) {
        viewModel.isSignalAlertOn.value = isOn
        let signalLower = viewModel.signalLowerBound.value
        let signalUpper = viewModel.signalUpperBound.value

        if let l = signalLower, let u = signalUpper {
            let type: AlertType = .signal(
                lower: l,
                upper: u
            )
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setSignalAlertLowerBound(lower: CGFloat) {
        let lowSignalDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.signalLowerBound.value = lower

        lowSignalDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                signal: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setSignalAlertUpperBound(upper: CGFloat) {
        let upperSignalDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.signalUpperBound.value = upper

        upperSignalDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                signal: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setSignalAlertDescription(description: String?) {
        viewModel.signalAlertDescription.value = description
        alertService.setSignal(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - Carbon Dioxide

extension TagSettingsPresenter {
    private func setCarbonDioxideAlertState(isOn: Bool) {
        viewModel.isCarbonDioxideAlertOn.value = isOn
        let carbonDiOxideLower = viewModel.carbonDioxideLowerBound.value
        let carbonDiOxideUpper = viewModel.carbonDioxideUpperBound.value

        if let l = carbonDiOxideLower, let u = carbonDiOxideUpper {
            let type: AlertType = .carbonDioxide(
                lower: l,
                upper: u
            )
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setCarbonDioxideAlertLowerBound(lower: CGFloat) {
        let lowCarbonDioxideDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.carbonDioxideLowerBound.value = lower

        lowCarbonDioxideDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                carbonDioxide: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setCarbonDioxideAlertUpperBound(upper: CGFloat) {
        let upperCarbonDioxideDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.carbonDioxideUpperBound.value = upper

        upperCarbonDioxideDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                carbonDioxide: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setCarbonDioxideAlertDescription(description: String?) {
        viewModel.carbonDioxideAlertDescription.value = description
        alertService.setCarbonDioxide(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - PMatter1

extension TagSettingsPresenter {
    private func setPMatter1AlertState(isOn: Bool) {
        viewModel.isPMatter1AlertOn.value = isOn
        if let pMatter1Lower = viewModel.pMatter1LowerBound.value,
           let pMatter1Upper = viewModel.pMatter1UpperBound.value {
            let type: AlertType = .pMatter1(lower: pMatter1Lower, upper: pMatter1Upper)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setPMatter1AlertLowerBound(lower: CGFloat) {
        let lowPMatter1Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter1LowerBound.value = lower

        lowPMatter1Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(pm1: lower, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setPMatter1AlertUpperBound(upper: CGFloat) {
        let upperPMatter1Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter1UpperBound.value = upper

        upperPMatter1Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(pm1: upper, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setPMatter1AlertDescription(description: String?) {
        viewModel.pMatter1AlertDescription.value = description
        alertService.setPM1(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - PMatter2_5

extension TagSettingsPresenter {
    private func setPMatter2_5AlertState(isOn: Bool) {
        viewModel.isPMatter2_5AlertOn.value = isOn
        if let pMatter2_5Lower = viewModel.pMatter2_5LowerBound.value,
           let pMatter2_5Upper = viewModel.pMatter2_5UpperBound.value {
            let type: AlertType = .pMatter2_5(lower: pMatter2_5Lower, upper: pMatter2_5Upper)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setPMatter2_5AlertLowerBound(lower: CGFloat) {
        let lowPMatter2_5Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter2_5LowerBound.value = lower

        lowPMatter2_5Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(pm2_5: lower, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setPMatter2_5AlertUpperBound(upper: CGFloat) {
        let upperPMatter2_5Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter2_5UpperBound.value = upper

        upperPMatter2_5Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(pm2_5: upper, ruuviTag: sSelf.ruuviTag)
            sSelf.processAlerts()
        }
    }

    private func setPMatter2_5AlertDescription(description: String?) {
        viewModel.pMatter2_5AlertDescription.value = description
        alertService.setPM2_5(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - PMatter4

extension TagSettingsPresenter {
    private func setPMatter4AlertState(isOn: Bool) {
        viewModel.isPMatter4AlertOn.value = isOn
        if let pMatter4Lower = viewModel.pMatter4LowerBound.value,
           let pMatter4Upper = viewModel.pMatter4UpperBound.value {
            let type: AlertType = .pMatter4(lower: pMatter4Lower, upper: pMatter4Upper)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setPMatter4AlertLowerBound(lower: CGFloat) {
        let lowPMatter4Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter4LowerBound.value = lower

        lowPMatter4Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                pm4: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPMatter4AlertUpperBound(upper: CGFloat) {
        let upperPMatter4Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter4UpperBound.value = upper

        upperPMatter4Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                pm4: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPMatter4AlertDescription(description: String?) {
        viewModel.pMatter4AlertDescription.value = description
        alertService.setPM4(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - PMatter10

extension TagSettingsPresenter {
    private func setPMatter10AlertState(isOn: Bool) {
        viewModel.isPMatter10AlertOn.value = isOn
        if let pMatter10Lower = viewModel.pMatter10LowerBound.value,
           let pMatter10Upper = viewModel.pMatter10UpperBound.value {
            let type: AlertType = .pMatter10(lower: pMatter10Lower, upper: pMatter10Upper)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setPMatter10AlertLowerBound(lower: CGFloat) {
        let lowPMatter10Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter10LowerBound.value = lower

        lowPMatter10Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                pm10: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPMatter10AlertUpperBound(upper: CGFloat) {
        let upperPMatter10Debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.pMatter10UpperBound.value = upper

        upperPMatter10Debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                pm10: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setPMatter10AlertDescription(description: String?) {
        viewModel.pMatter10AlertDescription.value = description
        alertService.setPM10(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - VOC

extension TagSettingsPresenter {
    private func setVOCAlertState(isOn: Bool) {
        viewModel.isVOCAlertOn.value = isOn
        if let vocLowerBound = viewModel.vocLowerBound.value,
           let vocUpperBound = viewModel.vocUpperBound.value {
            let type: AlertType = .voc(lower: vocLowerBound, upper: vocUpperBound)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setVOCAlertLowerBound(lower: CGFloat) {
        let lowVOCDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.vocLowerBound.value = lower

        lowVOCDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                voc: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setVOCAlertUpperBound(upper: CGFloat) {
        let upperVOCDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.vocUpperBound.value = upper

        upperVOCDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                voc: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setVOCAlertDescription(description: String?) {
        viewModel.vocAlertDescription.value = description
        alertService.setVOC(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - NOX

extension TagSettingsPresenter {
    private func setNOXAlertState(isOn: Bool) {
        viewModel.isNOXAlertOn.value = isOn
        if let noxLowerBound = viewModel.noxLowerBound.value,
              let noxUpperBound = viewModel.noxUpperBound.value {
            let type: AlertType = .nox(lower: noxLowerBound, upper: noxUpperBound)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setNOXAlertLowerBound(lower: CGFloat) {
        let lowNOXDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.noxLowerBound.value = lower

        lowNOXDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                nox: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setNOXAlertUpperBound(upper: CGFloat) {
        let upperNOXDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.noxUpperBound.value = upper

        upperNOXDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                nox: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setNOXAlertDescription(description: String?) {
        viewModel.noxAlertDescription.value = description
        alertService.setNOX(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - SOUND

extension TagSettingsPresenter {
    private func setSoundAlertState(isOn: Bool) {
        viewModel.isSoundAlertOn.value = isOn
        if let soundLowerBound = viewModel.soundLowerBound.value,
              let soundUpperBound = viewModel.soundUpperBound.value {
            let type: AlertType = .sound(lower: soundLowerBound, upper: soundUpperBound)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setSoundAlertLowerBound(lower: CGFloat) {
        let lowSoundDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.soundLowerBound.value = lower

        lowSoundDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                sound: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setSoundAlertUpperBound(upper: CGFloat) {
        let upperSoundDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.soundUpperBound.value = upper

        upperSoundDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                sound: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setSoundAlertDescription(description: String?) {
        viewModel.soundAlertDescription.value = description
        alertService.setSound(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - LUMINOSITY

extension TagSettingsPresenter {
    private func setLuminosityAlertState(isOn: Bool) {
        viewModel.isLuminosityAlertOn.value = isOn
        if let luminosityLowerBound = viewModel.luminosityLowerBound.value,
                let luminosityUpperBound = viewModel.luminosityUpperBound.value {
            let type: AlertType = .luminosity(lower: luminosityLowerBound, upper: luminosityUpperBound)
            let currentState = alertService.isOn(type: type, for: ruuviTag)
            if currentState != isOn {
                if isOn {
                    alertService.register(type: type, ruuviTag: ruuviTag)
                    processAlerts()
                } else {
                    alertService.unregister(type: type, ruuviTag: ruuviTag)
                }
                alertService.unmute(type: type, for: ruuviTag)
            }
        }
    }

    private func setLuminosityAlertLowerBound(lower: CGFloat) {
        let lowLuminosityDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.luminosityLowerBound.value = lower

        lowLuminosityDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setLower(
                luminosity: lower,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setLuminosityAlertUpperBound(upper: CGFloat) {
        let upperLuminosityDebouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.luminosityUpperBound.value = upper

        upperLuminosityDebouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setUpper(
                luminosity: upper,
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setLuminosityAlertDescription(description: String?) {
        viewModel.luminosityAlertDescription.value = description
        alertService.setLuminosity(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - MOVEMENT

extension TagSettingsPresenter {
    private func setMovementAlertState(isOn: Bool) {
        viewModel.isMovementAlertOn.value = isOn
        let last = viewModel.movementCounter.value ?? 0

        let type: AlertType = .movement(last: last)
        let currentState = alertService.isOn(type: type, for: ruuviTag)
        if currentState != isOn {
            if isOn {
                alertService.register(type: type, ruuviTag: ruuviTag)
                processAlerts()
            } else {
                alertService.unregister(type: type, ruuviTag: ruuviTag)
            }
            alertService.unmute(type: type, for: ruuviTag)
        }
    }

    private func setMovementAlertDescription(description: String?) {
        viewModel.movementAlertDescription.value = description
        alertService.setMovement(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

// MARK: - CONNECTION

extension TagSettingsPresenter {
    private func setConnectionAlertState(isOn: Bool) {
        viewModel.isConnectionAlertOn.value = isOn

        let type: AlertType = .connection
        let currentState = alertService.isOn(type: type, for: ruuviTag)
        if currentState != isOn {
            if isOn {
                alertService.register(type: type, ruuviTag: ruuviTag)
                processAlerts()
            } else {
                alertService.unregister(type: type, ruuviTag: ruuviTag)
            }
            alertService.unmute(type: type, for: ruuviTag)
        }
    }

    private func setConnectionAlertDescription(description: String?) {
        viewModel.connectionAlertDescription.value = description
        alertService.setConnection(
            description: description,
            for: ruuviTag
        )
    }
}

// MARK: - CLOUD CONNECTION

extension TagSettingsPresenter {
    private func setCloudConnectionAlertState(isOn: Bool) {
        viewModel.isCloudConnectionAlertOn.value = isOn
        let unseenDuration = viewModel.cloudConnectionAlertUnseenDuration.value ?? 900

        let type: AlertType = .cloudConnection(unseenDuration: unseenDuration)
        let currentState = alertService.isOn(type: type, for: ruuviTag)
        if currentState != isOn {
            if isOn {
                alertService.register(type: type, ruuviTag: ruuviTag)
            } else {
                alertService.unregister(type: type, ruuviTag: ruuviTag)
            }
            alertService.unmute(type: type, for: ruuviTag)
        }
    }

    private func setCloudConnectionAlertDelay(unseenDuration: Int) {
        let debouncer = Debouncer(delay: Self.lowUpperDebounceDelay)
        viewModel.cloudConnectionAlertUnseenDuration.value = Double(unseenDuration)

        debouncer.run { [weak self] in
            guard let sSelf = self else { return }
            sSelf.alertService.setCloudConnection(
                unseenDuration: Double(unseenDuration),
                ruuviTag: sSelf.ruuviTag
            )
            sSelf.processAlerts()
        }
    }

    private func setCloudConnectionAlertDescription(description: String?) {
        viewModel.cloudConnectionAlertDescription.value = description
        alertService.setCloudConnection(
            description: description,
            ruuviTag: ruuviTag
        )
    }
}

extension TagSettingsPresenter {
    private func notifyRestartAdvertisementDaemon() {
        // Notify daemon to restart
        NotificationCenter
            .default
            .post(
                name: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    private func notifyRestartHeartBeatDaemon() {
        // Notify daemon to restart
        NotificationCenter
            .default
            .post(
                name: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil,
                userInfo: nil
            )
    }

    func checkAndUpdateFirmwareVersion() {
        guard let luid = ruuviTag.luid,
              ruuviTag.firmwareVersion == nil ||
              !ruuviTag.firmwareVersion.hasText()
        else {
            return
        }

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid.value,
            options: [.connectionTimeout(15)]
        ) { [weak self] _, result in
            guard let sSelf = self else { return }
            switch result {
            case let .success(version):
                let tagWithVersion = sSelf.ruuviTag.with(firmwareVersion: version)
                self?.ruuviPool.update(tagWithVersion)
            default:
                break
            }
        }
    }

    private func removeTagAndCleanup() {
        // Disconnect the sensor first if paired.
        // Otherwise proceed to removal directly.
        if let luid = ruuviTag.luid,
           let isConnected = viewModel.isConnected.value,
           isConnected {
            connectionPersistence.setKeepConnection(false, for: luid)
            notifyRestartHeartBeatDaemon()
        }

        if ruuviTag.isOwner {
            notifyRestartAdvertisementDaemon()
            if let isConnected = viewModel.isConnected.value,
               isConnected {
                notifyRestartHeartBeatDaemon()
            }
        }
        viewModel.reset()
        localSyncState.setSyncDate(nil, for: ruuviTag.macId)
        localSyncState.setSyncDate(nil)
        localSyncState.setGattSyncDate(nil, for: ruuviTag.macId)
        settings.setOwnerCheckDate(for: ruuviTag.macId, value: nil)
    }

    private func presentActivityIndicator(with state: RuuviCloudRequestStateType) {
        switch state {
        case .loading:
            activityPresenter.show(
                with: .loading(
                    message: RuuviLocalization.activitySavingToCloud
                )
            )
        case .success:
            activityPresenter.update(
                with: .success(
                    message: RuuviLocalization.activitySavingSuccess
                )
            )
        case .failed:
            activityPresenter.update(
                with: .failed(
                    message: RuuviLocalization.activitySavingFail
                )
            )
        case .complete:
            activityPresenter.dismiss()
        }
    }
}

extension TagSettingsPresenter {
    private func emptySensorSettings() -> SensorSettings {
        SensorSettingsStruct(
            luid: ruuviTag.luid,
            macId: ruuviTag.macId,
            temperatureOffset: nil,
            humidityOffset: nil,
            pressureOffset: nil
        )
    }
}

extension TagSettingsPresenter: UIDocumentPickerDelegate {
    func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt _: [URL]) {
        if let url = exportFileUrl {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// swiftlint:enable file_length cyclomatic_complexity
