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
    weak var tagCharts: TagChartsModuleInput?
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordToken: RuuviReactorToken?
    private var virtualSensorsToken: VirtualReactorToken?
    private var virtualSensorsDataTokens = [VirtualReactorToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var rssiTokens = [AnyLocalIdentifier: ObservationToken]()
    private var rssiTimers = [AnyLocalIdentifier: Timer]()
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
    private var offsetCorrectionDidChangeToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var lnmDidReceiveToken: NSObjectProtocol?
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
    
    deinit {
        ruuviTagToken?.invalidate()
        virtualSensorsToken?.invalidate()
        ruuviTagObserveLastRecordToken?.invalidate()
        rssiTokens.values.forEach({ $0.invalidate() })
        rssiTimers.values.forEach({ $0.invalidate() })
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
    }
}

// MARK: - CardsViewOutput
extension CardsPresenter: CardsViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
        startObservingWebTags()
        startObservingSettingsChanges()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingConnectionPersistenceNotifications()
        startObservingDidConnectDisconnectNotifications()
        startObservingAlertChanges()
        startObservingLocalNotificationsManager()
        pushNotificationsManager.registerForRemoteNotifications()
    }
    
    func viewWillAppear() {
        startObservingBluetoothState()
    }
    
    func viewWillDisappear() {
        stopObservingBluetoothState()
    }
    
    func viewDidTriggerMenu() {
        router.openMenu(output: self)
    }
    
    func viewDidTriggerSettings(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi,
           let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
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
                output: self)
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
                || background.isConnected(uuid: luid.value) {
                router.openTagCharts()
            } else {
                view.showKeepConnectionDialog(for: viewModel)
            }
        } else if viewModel.mac.value != nil {
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidDismissKeepConnectionDialog(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnection(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
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

// MARK: - DiscoverModuleOutput
extension CardsPresenter: DiscoverModuleOutput {
    func discover(module: DiscoverModuleInput, didAddNetworkTag mac: String) {
        module.dismiss()
        self.startObservingRuuviTags()
    }
    
    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag) {
        module.dismiss()
        self.startObservingRuuviTags()
    }
    
    func discover(module: DiscoverModuleInput, didAddWebTag location: Location) {
        module.dismiss()
    }
    
    func discover(module: DiscoverModuleInput, didAddWebTag provider: VirtualProvider) {
        module.dismiss()
    }
}

// MARK: - MenuModuleOutput
extension CardsPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag sender: Any?) {
        module.dismiss()
        router.openDiscover(output: self)
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
        router.openRuuviWebsite()
    }

    func menu(module: MenuModuleInput, didSelectFeedback sender: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let sSelf = self else { return }
            sSelf.mailComposerPresenter.present(email: sSelf.feedbackEmail,
                                                subject: sSelf.feedbackSubject,
                                                body: "<br><br>" + summary)
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
            .filter({ $0.luid.value?.value == uuid })
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
            ruuviStorage.readLast(ruuviTag).on { record in
                if let record = record {
                    viewModel.update(record)
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
            && didLoadInitialWebTags
            && viewModels.isEmpty {
            self.router.openDiscover(output: self)
        }
    }
    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        guard !settings.tagsSorting.isEmpty else {
            return viewModels
        }
        return viewModels.reorder(by: settings.tagsSorting)
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
    private func startObservingSettingsChanges() {
        readRSSIToken = NotificationCenter
            .default
            .addObserver(forName: .ReadRSSIDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            if let readRSSI = self?.settings.readRSSI, readRSSI {
                                self?.observeRuuviTagRSSI()
                            } else {
                                self?.rssiTokens.values.forEach({ $0.invalidate() })
                                self?.rssiTimers.values.forEach({ $0.invalidate() })
                                self?.viewModels.forEach({ $0.update(rssi: nil) })
                            }
                         })
        readRSSIIntervalToken = NotificationCenter
            .default
            .addObserver(forName: .ReadRSSIIntervalDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.observeRuuviTagRSSI()
                         })
    }
    private func observeRuuviTags() {
        observeSensorSettings()
        restartObserveRuuviTagAdvertisements()
        observeRuuviTagHeartbeats()
        observeRuuviTagRSSI()
    }
    private func observeRuuviTagRSSI() {
        rssiTokens.values.forEach({ $0.invalidate() })
        rssiTimers.values.forEach({ $0.invalidate() })
        connectionPersistence.keepConnectionUUIDs
            .filter({ (luid) -> Bool in
                ruuviTags.contains(where: { $0.luid?.any == luid })
            }).forEach { (luid) in
                if settings.readRSSI {
                    let interval = settings.readRSSIIntervalSeconds
                    let timer = Timer
                        .scheduledTimer(withTimeInterval: TimeInterval(interval),
                                        repeats: true) { [weak self] timer in
                            guard let sSelf = self else { timer.invalidate(); return }
                            sSelf.rssiTokens[luid] = sSelf
                                .background
                                .readRSSI(for: sSelf,
                                          uuid: luid.value,
                                          result: { (observer, result) in
                                            switch result {
                                            case .success(let rssi):
                                                if let viewModel = observer.viewModels
                                                    .first(where: { $0.luid.value == luid }) {
                                                    viewModel.update(rssi: rssi, animated: true)
                                                }
                                            case .failure(let error):
                                                if case .logic(let logicError) = error, logicError == .notConnected {
                                                    // do nothing
                                                } else {
                                                    observer.errorPresenter.present(error: error)
                                                }
                                            }
                                          })
                        }
                    timer.fire()
                    rssiTimers[luid] = timer
                }
            }
    }
    private func observeRuuviTagHeartbeats() {
        heartbeatTokens.forEach({ $0.invalidate() })
        heartbeatTokens.removeAll()
        connectionPersistence.keepConnectionUUIDs.filter { (luid) -> Bool in
            ruuviTags.contains(where: { $0.luid?.any == luid })
        }.forEach { (luid) in
            heartbeatTokens.append(background.observe(self, uuid: luid.value) { [weak self] (_, device) in
                if let ruuviTag = device.ruuvi?.tag,
                   let viewModel = self?.viewModels.first(where: { $0.luid.value == ruuviTag.uuid.luid.any }) {
                    let sensorSettings = self?.sensorSettingsList
                        .first(where: {
                                ($0.luid?.any == viewModel.luid.value)
                                    || ($0.macId?.any == viewModel.mac.value)
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
            if viewModel.type == .ruuvi,
               let luid = viewModel.luid.value {
                advertisementTokens.append(foreground.observe(self, uuid: luid.value) { [weak self] (_, device) in
                    if let ruuviTag = device.ruuvi?.tag,
                       let viewModel = self?.viewModels.first(where: { $0.luid.value == ruuviTag.uuid.luid.any }) {
                        let sensorSettings = self?.sensorSettingsList
                            .first(where: {
                                    ($0.luid?.any == viewModel.luid.value)
                                        || ($0.macId?.any == viewModel.mac.value)
                            })
                        viewModel.update(
                            ruuviTag
                                .with(source: .advertisement)
                                .with(sensorSettings: sensorSettings)
                        )
                        viewModel.update(rssi: ruuviTag.rssi)
                    }
                })
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
                let previousDate = viewModel.date.value ?? Date.distantPast
                if previousDate <= record.date {
                    viewModel.update(record)
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
                let ruuviTags = ruuviTags.reordered(by: sSelf.settings)
                let isInitialLoad = sSelf.ruuviTags.count == 0
                sSelf.didLoadInitialRuuviTags = true
                sSelf.ruuviTags = ruuviTags.map({ $0.any })
                if isInitialLoad, let firstTag = ruuviTags.first {
                    sSelf.tagCharts?.configure(ruuviTag: firstTag)
                    sSelf.restartObservingRuuviTagLastRecord(for: firstTag)
                }
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
            case .insert(let sensor):
                sSelf.ruuviTags.append(sensor.any)
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
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
                            self?.observeRuuviTagRSSI()
                         })
        stopKeepingConnectionToken?.invalidate()
        stopKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStopToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                            self?.observeRuuviTagHeartbeats()
                            self?.observeRuuviTagRSSI()
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
                                if let settings = self?.settings, !settings.readRSSI {
                                    viewModel.update(rssi: nil)
                                }
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
                                        } else {
                                            viewModel.alertState.value = .empty
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
        ruuviTags.forEach({
            if let uuid = $0.luid?.value {
                alertHandler.subscribe(self, to: uuid)
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
}
// swiftlint:enable file_length trailing_whitespace
