// swiftlint:disable file_length trailing_whitespace
import Foundation
import BTKit
import Humidity
import RuuviOntology
import RuuviContext
import RuuviStorage
import RuuviReactor
import RuuviLocal
import RuuviService
import RuuviVirtual
import RuuviCore
import RuuviNotification
import RuuviNotifier
import RuuviDaemon
import RuuviPresenters
import RuuviUser

class CardsPresenter: CardsModuleInput {
    weak var view: CardsViewInput!
    var router: CardsRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var foreground: BTForeground!
    var background: BTBackground!
    var webTagService: VirtualService!
    var permissionPresenter: PermissionPresenter!
    var pushNotificationsManager: RuuviCorePN!
    var permissionsManager: RuuviCorePermission!
    var connectionPersistence: RuuviLocalConnections!
    var alertService: RuuviServiceAlert!
    var alertHandler: RuuviNotifier!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var ruuviReactor: RuuviReactor!
    var ruuviStorage: RuuviStorage!
    var virtualReactor: VirtualReactor!
    var measurementService: RuuviServiceMeasurement!
    var localSyncState: RuuviLocalSyncState!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var ruuviUser: RuuviUser!
    var featureToggleService: FeatureToggleService!
    weak var tagCharts: TagChartsModuleInput?
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordToken: RuuviReactorToken?
    private var virtualSensorsToken: VirtualReactorToken?
    private var virtualSensorsDataTokens = [VirtualReactorToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var backgroundToken: NSObjectProtocol?
    private var webTagDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    private var startKeepingConnectionToken: NSObjectProtocol?
    private var stopKeepingConnectionToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var alertDidChangeToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var universalLinkObservationToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var languageToken: NSObjectProtocol?
    private var widgetDeepLinkToken: NSObjectProtocol?
    private var virtualSensors = [AnyVirtualTagSensor]() {
        didSet {
            syncViewModels()
            startListeningToWebTagsAlertStatus()
        }
    }
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var viewModels = [CardsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    private var didLoadInitialRuuviTags = false
    private var didLoadInitialWebTags = false
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.ruuvi.station.widgets")
    
    deinit {
        ruuviTagToken?.invalidate()
        virtualSensorsToken?.invalidate()
        ruuviTagObserveLastRecordToken?.invalidate()
        advertisementTokens.forEach({ $0.invalidate() })
        heartbeatTokens.forEach({ $0.invalidate() })
        virtualSensorsDataTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.forEach({ $0.invalidate() })
        stateToken?.invalidate()
        backgroundToken?.invalidate()
        webTagDaemonFailureToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        startKeepingConnectionToken?.invalidate()
        stopKeepingConnectionToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        didConnectToken?.invalidate()
        didDisconnectToken?.invalidate()
        alertDidChangeToken?.invalidate()
        readRSSIToken?.invalidate()
        readRSSIIntervalToken?.invalidate()
        lnmDidReceiveToken?.invalidate()
        universalLinkObservationToken?.invalidate()
        cloudModeToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
        pressureUnitToken?.invalidate()
        languageToken?.invalidate()
        widgetDeepLinkToken?.invalidate()
    }
}

// MARK: - CardsViewOutput
extension CardsPresenter: CardsViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
        startObservingWebTags()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingConnectionPersistenceNotifications()
        startObservingDidConnectDisconnectNotifications()
        startObservingAlertChanges()
        startObservingLocalNotificationsManager()
        startObservingCloudModeNotification()
        startListeningToSettings()
        startObservingWidgetDeepLink()
        pushNotificationsManager.registerForRemoteNotifications()
    }
    
    func viewWillAppear() {
        startObservingUniversalLinks()
        startObservingBluetoothState()
        syncAppSettingsToAppGroupContainer()
    }
    
    func viewWillDisappear() {
        stopObservingBluetoothState()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }

    func viewDidTriggerAddSensors() {
        router.openDiscover()
    }

    func viewDidTriggerSettings(for viewModel: CardsViewModel, with scrollToAlert: Bool) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid.value {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || viewModel.isConnectable.value == false
                    || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                    openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
                } else {
                    view.showKeepConnectionDialogSettings(for: viewModel, scrollToAlert: scrollToAlert)
                }
            } else {
                openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
            }
        } else if viewModel.type == .web,
                  let webTag = virtualSensors.first(where: { $0.id == viewModel.id.value }) {
            router.openVirtualSensorSettings(
                sensor: webTag,
                temperature: viewModel.temperature.value
            )
        }
    }
    
    func viewDidTriggerChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            if settings.keepConnectionDialogWasShown(for: luid)
                || background.isConnected(uuid: luid.value)
                || viewModel.isConnectable.value == false
                || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                configureInitialChart(from: viewModel)
                router.openTagCharts()
            } else {
                view.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac.value != nil {
            // Setup initial tag chart
            configureInitialChart(from: viewModel)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel, scrollToAlert: Bool) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel, scrollToAlert: scrollToAlert)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid.value,
              let version = viewModel.version.value, version < 5,
              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup) else { return }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view.showFirmwareUpdateDialog(for: viewModel)
        }
    }
    
    func viewDidConfirmFirmwareUpdate(for viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.luid != nil && ($0.luid?.any == viewModel.luid.value))
            }) {
            router.openUpdateFirmware(ruuviTag: sensor)
        }
    }

    func viewDidIgnoreFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        view.showFirmwareDismissConfirmationUpdateDialog(for: viewModel)
    }
    
    func viewDidDismissFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        guard let luid = viewModel.luid.value else { return }
        settings.setFirmwareUpdateDialogWasShown(for: luid)
    }
    
    func viewDidScroll(to viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.luid != nil && ($0.luid?.any == viewModel.luid.value))
                || ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
            }) {
                restartObservingRuuviTagLastRecord(for: sensor)
                tagCharts?.configure(ruuviTag: sensor)
        } 
    }
}

// MARK: - MenuModuleOutput
extension CardsPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) {
        module.dismiss()
        router.openDiscover()
    }
    
    func menu(module: MenuModuleInput, didSelectSettings sender: Any?) {
        module.dismiss()
        router.openSettings()
    }
    
    func menu(module: MenuModuleInput, didSelectAbout sender: Any?) {
        module.dismiss()
        router.openAbout()
    }
    
    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?) {
        module.dismiss()
        router.openRuuviProductsPage()
    }

    func menu(module: MenuModuleInput, didSelectGetRuuviGateway sender: Any?) {
        module.dismiss()
        router.openRuuviGatewayPage()
    }

    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let sSelf = self else { return }
            sSelf.mailComposerPresenter.present(email: sSelf.feedbackEmail,
                                                subject: sSelf.feedbackSubject,
                                                body: "\n\n" + summary)
        }
    }
    func menu(module: MenuModuleInput, didSelectSignIn sender: Any?) {
        module.dismiss()
        router.openSignIn(output: self)
    }
    func menu(module: MenuModuleInput, didSelectOpenConfig sender: Any?) {
        module.dismiss()
    }
}

// MARK: - SignInModuleOutput
extension CardsPresenter: SignInModuleOutput {
    func signIn(module: SignInModuleInput, didSuccessfulyLogin sender: Any?) {
        module.dismiss()
    }
}

// MARK: - TagChartsModuleOutput
extension CardsPresenter: TagChartsModuleOutput {
    func tagCharts(module: TagChartsModuleInput, didScrollTo uuid: String) {
        if let index = viewModels.firstIndex(where: { $0.luid.value?.value == uuid }) {
            view.scroll(to: index, immediately: true, animated: false)
        }
    }
    func tagChartsDidDeleteTag(module: TagChartsModuleInput) {
        module.dismiss(completion: { [weak self] in
            self?.startObservingRuuviTags()
        })
    }
}

// MARK: - CardsRouterDelegate
extension CardsPresenter: CardsRouterDelegate {
    func shouldDismissDiscover() -> Bool {
        return viewModels.count > 0
    }
}

// MARK: - RuuviNotifierObserver
extension CardsPresenter: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        viewModels
            .filter({ $0.luid.value?.value == uuid ||  $0.mac.value?.value == uuid})
            .forEach({
                let newValue: AlertState = isTriggered ? .firing : .registered
                if newValue != $0.alertState.value {
                    $0.alertState.value = newValue
                }
            })
    }
}

// MARK: - TagSettingsModuleOutput
extension CardsPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput, ruuviTag: RuuviTagSensor) {
        module.dismiss(completion: { [weak self] in
            self?.startObservingRuuviTags()
        })
    }
}

// MARK: - Private
extension CardsPresenter {
    // swiftlint:disable:next function_body_length
    private func syncViewModels() {
        let ruuviViewModels = ruuviTags.compactMap({ (ruuviTag) -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: { image in
                    viewModel.background.value = image
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            if let luid = ruuviTag.luid {
                viewModel.isConnected.value = background.isConnected(uuid: luid.value)
            } else if let macId = ruuviTag.macId {
                viewModel.networkSyncStatus.value = localSyncState.getSyncStatus(for: macId)
                viewModel.isConnected.value = false
            } else {
                assertionFailure()
            }
            viewModel.alertState.value = alertService
                .hasRegistrations(for: ruuviTag) ? .registered : .empty
            viewModel.rhAlertLowerBound.value = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound.value = alertService
                .upperRelativeHumidity(for: ruuviTag)
            
            ruuviStorage.readLast(ruuviTag).on { [weak self] record in
                if let record = record {
                    viewModel.update(record)
                    if viewModel.luid.value != nil {
                        self?.alertHandler.process(record: record, trigger: false)
                    } else {
                        guard let macId = viewModel.mac.value else {
                            return
                        }
                        self?.alertHandler.processNetwork(record: record, trigger: false, for: macId)
                    }
                }
            }
            return viewModel
        })
        let virtualViewModels = virtualSensors.compactMap({ virtualSensor -> CardsViewModel in
            let viewModel = CardsViewModel(virtualSensor)
            ruuviSensorPropertiesService.getImage(for: virtualSensor)
                .on(success: { image in
                    viewModel.background.value = image
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            viewModel.alertState.value = alertService.hasRegistrations(for: virtualSensor) ? .registered : .empty
            viewModel.isConnected.value = false
            return viewModel
        })
        viewModels = reorder(ruuviViewModels + virtualViewModels)
        // if no tags, open discover
        if didLoadInitialRuuviTags
            && didLoadInitialWebTags {
            self.view.showNoSensorsAddedMessage(show: viewModels.isEmpty)
        }
    }

    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        return viewModels.sorted(by: {
            // Sort sensors by name alphabetically
            if let first = $0.name.value?.lowercased(), let second = $1.name.value?.lowercased() {
                return first < second
            } else {
                return true
            }
        })
    }

    private func syncAppSettingsToAppGroupContainer() {
        let languageKey = "languageKey"
        appGroupDefaults?.set(settings.language.rawValue, forKey: languageKey)
    
        let temperatureUnitKey = "temperatureUnitKey"
        var temperatureUnitInt: Int = 2
        switch settings.temperatureUnit {
        case .kelvin:
            temperatureUnitInt = 1
        case .celsius:
            temperatureUnitInt = 2
        case .fahrenheit:
            temperatureUnitInt = 3
        }
        appGroupDefaults?.set(temperatureUnitInt, forKey: temperatureUnitKey)
        
        var humidityUnitInt: Int = 0
        switch settings.humidityUnit {
        case .percent:
            humidityUnitInt = 0
        case .gm3:
            humidityUnitInt = 1
        case .dew:
            humidityUnitInt = 2
        }
        let humidityUnitKey = "humidityUnitKey"
        appGroupDefaults?.set(humidityUnitInt, forKey: humidityUnitKey)
    
        let pressureUnitKey = "pressureUnitKey"
        appGroupDefaults?.set(settings.pressureUnit.hashValue, forKey: pressureUnitKey)
    }

    private func configureInitialChart(from viewModel: CardsViewModel) {
        if let sensor = ruuviTags
            .first(where: {
                ($0.macId != nil && ($0.macId?.any == viewModel.mac.value))
            }) {
            tagCharts?.configure(ruuviTag: sensor)
        }
    }
    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
            if state != .poweredOn {
                observer.view.showBluetoothDisabled()
            }
        })
    }
    private func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }
    private func observeRuuviTags() {
        observeSensorSettings()
        restartObserveRuuviTagAdvertisements()
        observeRuuviTagHeartbeats()
    }
    private func observeRuuviTagHeartbeats() {
        heartbeatTokens.forEach({ $0.invalidate() })
        heartbeatTokens.removeAll()
        connectionPersistence.keepConnectionUUIDs.filter { (luid) -> Bool in
            ruuviTags.filter({ !(settings.cloudModeEnabled && $0.isCloud) })
                .contains(where: { $0.luid?.any != nil && $0.luid?.any == luid })
        }.forEach { (luid) in
            heartbeatTokens.append(background.observe(self, uuid: luid.value) { [weak self] (_, device) in
                if let ruuviTag = device.ruuvi?.tag,
                   let viewModel = self?.viewModels.first(where: { $0.luid.value == ruuviTag.uuid.luid.any }) {
                    let sensorSettings = self?.sensorSettingsList
                        .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
                        })
                    viewModel.update(
                        ruuviTag
                            .with(source: .heartbeat)
                            .with(sensorSettings: sensorSettings)
                    )
                }
            })
        }
    }
    private func restartObserveRuuviTagAdvertisements() {
        advertisementTokens.forEach({ $0.invalidate() })
        advertisementTokens.removeAll()
        for viewModel in viewModels {
            if !(settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                if viewModel.type == .ruuvi,
                   let luid = viewModel.luid.value {
                    advertisementTokens.append(foreground.observe(self, uuid: luid.value) { [weak self] (_, device) in
                        if let ruuviTag = device.ruuvi?.tag,
                           let viewModel = self?.viewModels.first(where: { $0.luid.value == ruuviTag.uuid.luid.any }) {
                            let sensorSettings = self?.sensorSettingsList
                                .first(where: {
                                    ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
                                })
                            let record = ruuviTag
                                .with(source: .advertisement)
                                .with(sensorSettings: sensorSettings)
                            viewModel.update(record)
                            self?.alertHandler.process(record: record, trigger: false)
                        }
                    })
                }
            }
        }
    }
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor, { [weak self] change in
                        self?.restartObservingRuuviTagLastRecord(for: ruuviTagSensor)
                        switch change {
                        case .insert(let sensorSettings):
                            self?.sensorSettingsList.append(sensorSettings)
                        case .update(let updateSensorSettings):
                            if let updateIndex = self?.sensorSettingsList.firstIndex(
                                where: { $0.id == updateSensorSettings.id }
                            ) {
                                self?.sensorSettingsList[updateIndex] = updateSensorSettings
                            } else {
                                self?.sensorSettingsList.append(updateSensorSettings)
                            }
                        case .delete(let deleteSensorSettings):
                            if let deleteIndex = self?.sensorSettingsList.firstIndex(
                                where: { $0.id == deleteSensorSettings.id }
                            ) {
                                self?.sensorSettingsList.remove(at: deleteIndex)
                            }
                        default: break
                        }
                    })
                )
            }
        }
    }
    private func restartObservingRuuviTagLastRecord(for sensor: AnyRuuviTagSensor) {
        ruuviTagObserveLastRecordToken?.invalidate()
        ruuviTagObserveLastRecordToken = ruuviReactor.observeLast(sensor) { [weak self] (changes) in
            if case .update(let anyRecord) = changes,
               let viewModel = self?.viewModels
                .first(where: {
                    ($0.luid.value != nil && ($0.luid.value == anyRecord?.luid?.any))
                    || ($0.mac.value != nil && ($0.mac.value == anyRecord?.macId?.any))
                }),
               let record = anyRecord {
                let sensorSettings = self?.sensorSettingsList
                    .first(where: {
                            ($0.luid?.any != nil && $0.luid?.any == viewModel.luid.value)
                                || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac.value)
                    })
                let sensorRecord = record.with(sensorSettings: sensorSettings)
                viewModel.update(sensorRecord)

                if viewModel.luid.value != nil {
                    self?.alertHandler.process(record: sensorRecord, trigger: false)
                } else {
                    guard let macId = viewModel.mac.value else {
                        return
                    }
                    self?.alertHandler.processNetwork(record: sensorRecord, trigger: false, for: macId)
                }
            }
        }
    }
    private func restartObservingVirtualSensorsData() {
        virtualSensorsDataTokens.forEach({ $0.invalidate() })
        virtualSensorsDataTokens.removeAll()
        virtualSensors.forEach { virtualSensor in
            virtualSensorsDataTokens
                .append(virtualReactor.observeLast(virtualSensor, { [weak self] changes in
                    if case .update(let anyRecord) = changes,
                       let viewModel = self?.viewModels
                        .first(where: { $0.id.value == anyRecord?.sensorId }),
                       let record = anyRecord {
                        let previousDate = viewModel.date.value ?? Date.distantPast
                        if previousDate <= record.date {
                            viewModel.update(record)
                        }
                    }
                }))
        }
    }

    private func startObservingWebTags() {
        virtualSensorsToken?.invalidate()
        virtualSensorsToken = virtualReactor.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let sensors):
                sSelf.didLoadInitialWebTags = true
                sSelf.virtualSensors = sensors
                sSelf.restartObservingVirtualSensorsData()
            case .delete(let sensor):
                sSelf.virtualSensors.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                sSelf.restartObservingVirtualSensorsData()
            case .update(let sensor):
                if let index = sSelf.virtualSensors
                    .firstIndex(
                        where: {
                            $0.id == sensor.id
                        }) {
                    sSelf.virtualSensors[index] = sensor
                    sSelf.syncViewModels()
                    sSelf.restartObserveRuuviTagAdvertisements()
                }
            case .insert(let sensor):
                sSelf.virtualSensors.append(sensor)
                if let index = sSelf.viewModels.firstIndex(where: { $0.id.value == sensor.id }) {
                    sSelf.view.scroll(to: index)
                }
                if !sSelf.settings.cardsSwipeHintWasShown, sSelf.viewModels.count > 1 {
                    sSelf.view.showSwipeLeftRightHint()
                    sSelf.settings.cardsSwipeHintWasShown = true
                }
                sSelf.restartObservingVirtualSensorsData()
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let ruuviTags):
                let ruuviTags = ruuviTags.reordered()
                let isInitialLoad = sSelf.ruuviTags.count == 0
                sSelf.didLoadInitialRuuviTags = true
                sSelf.ruuviTags = ruuviTags
                if isInitialLoad, let firstTag = ruuviTags.first {
                    sSelf.tagCharts?.configure(ruuviTag: firstTag)
                    sSelf.restartObservingRuuviTagLastRecord(for: firstTag)
                }
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                if let viewModel = sSelf.viewModels.first {
                    sSelf.viewDidTriggerFirmwareUpdateDialog(for: viewModel)
                }
            case .insert(let sensor):
                sSelf.ruuviTags.append(sensor.any)
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                if let index = sSelf.viewModels.firstIndex(where: {
                    return ($0.luid.value != nil && $0.luid.value == sensor.luid?.any)
                        || ($0.mac.value != nil && $0.mac.value == sensor.macId?.any)
                }) {
                    sSelf.view.scroll(to: index)
                    sSelf.restartObservingRuuviTagLastRecord(for: sensor)
                    sSelf.tagCharts?.configure(ruuviTag: sensor)
                    if !sSelf.settings.cardsSwipeHintWasShown, sSelf.viewModels.count > 1 {
                        sSelf.view.showSwipeLeftRightHint()
                        sSelf.settings.cardsSwipeHintWasShown = true
                    }
                }
            case .delete(let sensor):
                sSelf.ruuviTags.removeAll(where: { $0.id == sensor.id })
                if let last = sSelf.ruuviTags.last {
                    sSelf.tagCharts?.configure(ruuviTag: last)
                }
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                if sSelf.view.currentPage < sSelf.ruuviTags.count {
                    let tag = sSelf.ruuviTags[sSelf.view.currentPage]
                    sSelf.restartObservingRuuviTagLastRecord(for: tag)
                } else {
                    sSelf.ruuviTagObserveLastRecordToken?.invalidate()
                }
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            case .update(let sensor):
                guard let sSelf = self else { return }
                if let index = sSelf.ruuviTags
                    .firstIndex(
                        where: {
                            ($0.macId != nil && $0.macId?.any == sensor.macId?.any)
                            || ($0.luid != nil && $0.luid?.any == sensor.luid?.any)
                        }) {
                    sSelf.ruuviTags[index] = sensor
                    sSelf.syncViewModels()
                    sSelf.restartObserveRuuviTagAdvertisements()
                }
                sSelf.startObservingWebTags()
            }
        }
    }
    private func startObservingBackgroundChanges() {
        backgroundToken?.invalidate()
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in

                guard let sSelf = self else { return }
                if let userInfo = notification.userInfo {
                    let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier
                    let macId = userInfo[BPDidChangeBackgroundKey.macId] as? MACIdentifier
                    let viewModel = sSelf.view.viewModels
                        .first(where: { $0.luid.value != nil && $0.luid.value == luid?.any })
                        ?? sSelf.view.viewModels
                        .first(where: { $0.mac.value != nil && $0.mac.value == macId?.any })
                    if let viewModel = viewModel {
                        let ruuviTag = sSelf.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                            ?? sSelf.ruuviTags
                            .first(where: { $0.macId != nil && $0.macId?.any == macId?.any })
                        let webTag = sSelf.virtualSensors.first(where: { $0.id == luid?.value })
                        if let ruuviTag = ruuviTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                }, failure: { [weak self] error in
                                    self?.errorPresenter.present(error: error)
                                })
                        }
                        if let webTag = webTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: webTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                }, failure: { [weak sSelf] error in
                                    sSelf?.errorPresenter.present(error: error)
                                })
                        }
                    }
                }
            }
    }
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func startObservingDaemonsErrors() {
        webTagDaemonFailureToken?.invalidate()
        webTagDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .WebTagDaemonDidFail,
                         object: nil,
                         queue: .main) { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let error = userInfo[WebTagDaemonDidFailKey.error] as? RUError {
                    if case .core(let coreError) = error, coreError == .locationPermissionDenied {
                        self?.permissionPresenter.presentNoLocationPermission()
                    } else if case .core(let coreError) = error, coreError == .locationPermissionNotDetermined {
                        self?.permissionsManager.requestLocationPermission { [weak self] (granted) in
                            if !granted {
                                self?.permissionPresenter.presentNoLocationPermission()
                            }
                        }
                    } else if case .virtualService(let serviceError) = error,
                              case .openWeatherMap(let owmError) = serviceError,
                              owmError == OWMError.apiLimitExceeded {
                        self?.view.showWebTagAPILimitExceededError()
                    } else if case .map(let mapError) = error {
                        let nsError = mapError as NSError
                        if nsError.code == 2, nsError.domain == "kCLErrorDomain" {
                            self?.view.showReverseGeocodingFailed()
                        } else {
                            self?.errorPresenter.present(error: error)
                        }
                    } else {
                        self?.errorPresenter.present(error: error)
                    }
                }
            }
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagAdvertisementDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagPropertiesDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagHeartbeatDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagReadLogsOperationDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? RUError {
                                self?.errorPresenter.present(error: error)
                            }
                         })
    }
    func startObservingConnectionPersistenceNotifications() {
        startKeepingConnectionToken?.invalidate()
        startKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStartToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.observeRuuviTagHeartbeats()
                         })
        stopKeepingConnectionToken?.invalidate()
        stopKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStopToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.observeRuuviTagHeartbeats()
                         })
    }
    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken?.invalidate()
        didConnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidConnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                               let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                                viewModel.isConnected.value = true
                            }
                         })
        didDisconnectToken?.invalidate()
        didDisconnectToken = NotificationCenter
            .default
            .addObserver(forName: .BTBackgroundDidDisconnect,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let userInfo = notification.userInfo,
                               let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                               let viewModel = self?.viewModels.first(where: { $0.luid.value == uuid.luid.any }) {
                                viewModel.isConnected.value = false
                            }
                         })
    }
    private func startObservingAlertChanges() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            guard let sSelf = self else { return }
                            if let userInfo = notification.userInfo {
                               if let physicalSensor
                                    = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor {
                                sSelf.viewModels.filter({
                                    ($0.luid.value != nil && ($0.luid.value == physicalSensor.luid?.any))
                                        || ($0.mac.value != nil && ($0.mac.value == physicalSensor.macId?.any))
                                    }).forEach({ (viewModel) in
                                        if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                                            viewModel.alertState.value = .registered
                                            viewModel.rhAlertLowerBound.value = sSelf.alertService
                                                .lowerRelativeHumidity(for: physicalSensor)
                                            viewModel.rhAlertUpperBound.value = sSelf.alertService
                                                .upperRelativeHumidity(for: physicalSensor)
                                        } else {
                                            viewModel.alertState.value = .empty
                                            viewModel.rhAlertLowerBound.value = 0
                                            viewModel.rhAlertUpperBound.value = 100
                                        }
                                    })
                                }
                                if let virtualSensor
                                    = userInfo[RuuviServiceAlertDidChangeKey.virtualSensor] as? VirtualSensor {
                                 sSelf.viewModels.filter({
                                    ($0.id.value != nil && ($0.id.value == virtualSensor.id))
                                 }).forEach({ (viewModel) in
                                         if sSelf.alertService.hasRegistrations(for: virtualSensor) {
                                             viewModel.alertState.value = .registered
                                         } else {
                                             viewModel.alertState.value = .empty
                                         }
                                     })
                                 }
                             }
                         })
    }
    private func startListeningToRuuviTagsAlertStatus() {
        ruuviTags.forEach({ (ruuviTag) in
            if let luid = ruuviTag.luid {
                alertHandler.subscribe(self, to: luid.value)
            } else if let macId = ruuviTag.macId {
                alertHandler.subscribe(self, to: macId.value)
            }
        })
    }
    private func startListeningToWebTagsAlertStatus() {
        virtualSensors.forEach({ alertHandler.subscribe(self, to: $0.id) })
    }
    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken?.invalidate()
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(forName: .LNMDidReceive,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                            if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String,
                               let index = self?.viewModels.firstIndex(where: { $0.luid.value == uuid.luid.any }),
                               let ruuviTag = self?.ruuviTags.first(where: { $0.luid?.value == uuid }) {
                                self?.view.scroll(to: index)
                                self?.tagCharts?.configure(ruuviTag: ruuviTag)
                            }
                         })
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel, scrollToAlert: Bool) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            var humidity: Humidity?
            if let temperature = viewModel.temperature.value {
                humidity = viewModel.humidity.value?
                    .converted(to: .relative(temperature: temperature))
            }
            self.router.openTagSettings(
                ruuviTag: ruuviTag,
                temperature: viewModel.temperature.value,
                humidity: humidity,
                sensorSettings: sensorSettingsList
                    .first(where: {
                        ($0.luid != nil && $0.luid?.any == viewModel.luid.value)
                        || ($0.macId != nil && $0.macId?.any == viewModel.mac.value)
                    }),
                output: self,
                scrollToAlert: scrollToAlert)
        }
    }

    private func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter
            .default
            .addObserver(forName: .DidOpenWithUniversalLink,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                guard let email = self?.ruuviUser.email else { return }
                self?.view.showAlreadyLoggedInAlert(with: email)
        })
    }

    private func startObservingCloudModeNotification() {
        cloudModeToken?.invalidate()
        cloudModeToken = NotificationCenter
            .default
            .addObserver(forName: .CloudModeDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                // Do something here
                self?.handleCloudModeState()
            })
    }

    private func handleCloudModeState() {
        // Disconnect the owned cloud tags
        removeConnectionsForCloudTags()
        // Stop listening to advertisements and heartbeats
        observeRuuviTags()
        // Update viewmodel data source to ruuvi network from heartbeats/advertisements
        updateViewModelsSource()
    }

    private func removeConnectionsForCloudTags() {
        connectionPersistence.keepConnectionUUIDs.filter { (luid) -> Bool in
            ruuviTags.filter({ $0.isCloud }).contains(where: { $0.luid?.any != nil && $0.luid?.any == luid })
        }.forEach { (luid) in
            connectionPersistence.setKeepConnection(false, for: luid)
        }
    }
    
    private func updateViewModelsSource() {
        let vms = viewModels
        guard settings.cloudModeEnabled else { return }
        vms.indices.forEach {
            if vms[$0].luid.value != nil && vms[$0].isCloud.value.bound {
                vms[$0].source.value = .ruuviNetwork
            }
        }
        viewModels = vms
    }
    
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
        })
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
        })
        languageToken = NotificationCenter
            .default
            .addObserver(forName: .LanguageDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
        })
    }
    
    private func startObservingWidgetDeepLink() {
        languageToken = NotificationCenter
            .default
            .addObserver(forName: .DidOpenWithWidgetDeepLink,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                if let userInfo = notification.userInfo,
                   let macId = userInfo[WidgetDeepLinkMacIdKey.macId] as? String,
                   let index = self?.viewModels.firstIndex(where: { viewModel in
                       viewModel.mac.value?.value == macId
                   }) {
                    self?.view.scroll(to: index)
                }
            })
    }
}
// swiftlint:enable file_length trailing_whitespace
