// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit
import Humidity

class CardsPresenter: CardsModuleInput {
    weak var view: CardsViewInput!
    var router: CardsRouterInput!
    var realmContext: RealmContext!
    var errorPresenter: ErrorPresenter!
    var settings: Settings!
    var backgroundPersistence: BackgroundPersistence!
    var foreground: BTForeground!
    var background: BTBackground!
    var webTagService: WebTagService!
    var permissionPresenter: PermissionPresenter!
    var pushNotificationsManager: PushNotificationsManager!
    var permissionsManager: PermissionsManager!
    var connectionPersistence: ConnectionPersistence!
    var alertService: AlertService!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var calibrationService: CalibrationService!
    var ruuviTagReactor: RuuviTagReactor!
    var ruuviTagTrunk: RuuviTagTrunk!
    var virtualTagReactor: VirtualTagReactor!

    weak var tagCharts: TagChartsModuleInput?

    private var ruuviTagToken: RUObservationToken?
    private var ruuviTagObserveLastRecordToken: RUObservationToken?
    private var webTagsToken: NotificationToken?
    private var webTagsDataTokens = [NotificationToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var rssiTokens = [AnyLocalIdentifier: ObservationToken]()
    private var rssiTimers = [AnyLocalIdentifier: Timer]()
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
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
    private var calibrationHumidityDidChangeToken: NSObjectProtocol?
    private var didMigrationCompleteToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var lnmDidReceiveToken: NSObjectProtocol?
    private var virtualTags: Results<WebTagRealm>? {
        didSet {
            syncViewModels()
            startListeningToWebTagsAlertStatus()
        }
    }
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var viewModels = [CardsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }
    private var didLoadInitialRuuviTags = false
    private var didLoadInitialWebTags = false

    // swiftlint:disable:next cyclomatic_complexity,function_body_length
    deinit {
        ruuviTagToken?.invalidate()
        webTagsToken?.invalidate()
        ruuviTagObserveLastRecordToken?.invalidate()
        rssiTokens.values.forEach({ $0.invalidate() })
        rssiTimers.values.forEach({ $0.invalidate() })
        advertisementTokens.forEach({ $0.invalidate() })
        heartbeatTokens.forEach({ $0.invalidate() })
        webTagsDataTokens.forEach({ $0.invalidate() })
        stateToken?.invalidate()
        temperatureUnitToken?.invalidate()
        humidityUnitToken?.invalidate()
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
        calibrationHumidityDidChangeToken?.invalidate()
        didMigrationCompleteToken?.invalidate()
    }
}

// MARK: - CardsViewOutput
extension CardsPresenter: CardsViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
        startObserveMigrationCompletion()
        startObservingWebTags()
        startObservingSettingsChanges()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingConnectionPersistenceNotifications()
        startObservingDidConnectDisconnectNotifications()
        startObservingAlertChanges()
        startObservingCalibrationHumidityChanges()
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
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: viewModel.relativeHumidity.value, output: self)
        } else if viewModel.type == .web,
            let webTag = virtualTags?.first(where: { $0.uuid == viewModel.luid.value?.value }) {
            router.openWebTagSettings(webTag: webTag)
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
        if let luid = viewModel.luid.value,
            let sensor = ruuviTags.first(where: {$0.luid?.any == luid}) {
            restartObservingRuuviTagNetwork(for: sensor)
            tagCharts?.configure(ruuviTag: sensor)
        }
    }
}

// MARK: - DiscoverModuleOutput
extension CardsPresenter: DiscoverModuleOutput {
    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag) {
        module.dismiss()
        self.startObservingRuuviTags()
    }

    func discover(module: DiscoverModuleInput, didAddWebTag location: Location) {
        module.dismiss()
    }

    func discover(module: DiscoverModuleInput, didAddWebTag provider: WeatherProvider) {
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
                                                body: "\n\n" + summary)
        }
    }
}

// MARK: - TagChartsModuleOutput
extension CardsPresenter: TagChartsModuleOutput {
    func tagCharts(module: TagChartsModuleInput, didScrollTo uuid: String) {
        if let index = viewModels.firstIndex(where: { $0.luid.value?.value == uuid }) {
            view.scroll(to: index, immediately: true)
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

// MARK: - AlertServiceObserver
extension CardsPresenter: AlertServiceObserver {
    func alert(service: AlertService, isTriggered: Bool, for uuid: String) {
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
            if let luid = ruuviTag.luid {
                viewModel.background.value = backgroundPersistence.background(for: luid)
                viewModel.humidityOffset.value = calibrationService.humidityOffset(for: luid).0
                viewModel.humidityOffsetDate.value = calibrationService.humidityOffset(for: luid).1
                viewModel.isConnected.value = background.isConnected(uuid: luid.value)
                viewModel.alertState.value = alertService.hasRegistrations(for: luid.value) ? .registered : .empty
            } else if let macId = ruuviTag.macId {
                // FIXME viewModel.background.value = backgroundPersistence.background(for: macId)
                // viewModel.humidityOffset.value = calibrationService.humidityOffset(for: macId).0
                // viewModel.humidityOffsetDate.value = calibrationService.humidityOffset(for: macId).1
                // viewModel.isConnected.value = background.isConnected(uuid: luid.value)
                // viewModel.alertState.value = alertService.hasRegistrations(for: luid.value) ? .registered : .empty
                viewModel.isConnected.value = false
                viewModel.alertState.value = .empty
            } else {
                assertionFailure()
            }
            viewModel.humidityUnit.value = settings.humidityUnit
            viewModel.temperatureUnit.value = settings.temperatureUnit
            ruuviTagTrunk.readLast(ruuviTag).on { [weak self] record in
                if let record = record {
                    viewModel.update(record)
                    self?.updateAlertState(for: viewModel)
                }
            }
            return viewModel
        })

        var virtualViewModels = [CardsViewModel]()
        if virtualTags != nil {
            virtualViewModels = virtualTags?.compactMap({ (webTag) -> CardsViewModel in
                let viewModel = CardsViewModel(webTag)
                viewModel.humidityUnit.value = settings.humidityUnit
                viewModel.background.value = backgroundPersistence.background(for: webTag.uuid.luid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.alertState.value = alertService.hasRegistrations(for: webTag.uuid) ? .registered : .empty
                viewModel.isConnected.value = false
                return viewModel
            }) ?? []
        }
        viewModels = ruuviViewModels + virtualViewModels

        // if no tags, open discover
        if didLoadInitialRuuviTags
            && didLoadInitialWebTags
            && viewModels.isEmpty {
            self.router.openDiscover(output: self)
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

    private func startObservingSettingsChanges() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] (_) in
            self?.viewModels.forEach({ $0.temperatureUnit.value = self?.settings.temperatureUnit })
        }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityUnitDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.viewModels.forEach({ $0.humidityUnit.value = self?.settings.humidityUnit })
        })
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
        observeRuuviTagAdvertisements()
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
                                if let viewModel = observer.viewModels.first(where: { $0.luid.value == luid }) {
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
                    viewModel.update(with: ruuviTag)
                    self?.updateAlertState(for: viewModel)
                }
            })
        }
    }

    private func observeRuuviTagAdvertisements() {
        advertisementTokens.forEach({ $0.invalidate() })
        advertisementTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi, let luid = viewModel.luid.value {
                advertisementTokens.append(foreground.observe(self, uuid: luid.value) { [weak self] (_, device) in
                    if let ruuviTag = device.ruuvi?.tag,
                        let viewModel = self?.viewModels.first(where: { $0.luid.value == ruuviTag.uuid.luid.any }) {
                        viewModel.update(with: ruuviTag)
                        viewModel.update(rssi: ruuviTag.rssi)
                        self?.updateAlertState(for: viewModel)
                    }
                })
            }
        }
    }

    private func restartObservingRuuviTagNetwork(for sensor: AnyRuuviTagSensor) {
        ruuviTagObserveLastRecordToken?.invalidate()
        ruuviTagObserveLastRecordToken = ruuviTagReactor.observeLast(sensor) { [weak self] (changes) in
            if case .update(let anyRecord) = changes,
                let viewModel = self?.viewModels.first(where: {$0.id.value == anyRecord?.ruuviTagId}),
                let record = anyRecord?.object {
                if viewModel.needUpdateFromObservingLastRecord {
                    viewModel.update(record)
                }
            }
        }
    }

    private func startObservingWebTagsData() {
        webTagsDataTokens.forEach({ $0.invalidate() })
        webTagsDataTokens.removeAll()

        virtualTags?.forEach({ webTag in
            webTagsDataTokens.append(webTag.data.observe { [weak self] (change) in
                switch change {
                case .initial(let data):
                    if let last = data.sorted(byKeyPath: "date").last {
                        self?.viewModels
                            .filter({ $0.luid.value == webTag.uuid.luid.any })
                            .forEach({ $0.update(last)})
                    }
                case .update(let data, _, _, _):
                    if let last = data.sorted(byKeyPath: "date").last {
                        self?.viewModels
                            .filter({ $0.luid.value == webTag.uuid.luid.any })
                            .forEach({ $0.update(last)})
                    }
                case .error(let error):
                    self?.errorPresenter.present(error: error)
                }
            })
        })
    }

    private func startObservingWebTags() {
        webTagsToken = realmContext.main.objects(WebTagRealm.self).observe({ [weak self] (change) in
            switch change {
            case .initial(let webTags):
                self?.didLoadInitialWebTags = true
                self?.virtualTags = webTags
                self?.startObservingWebTagsData()
            case .update(let webTags, _, let insertions, _):
                self?.virtualTags = webTags
                if let ii = insertions.last {
                    let uuid = webTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.luid.value == uuid.luid.any }) {
                        self?.view.scroll(to: index)
                    }
                    if let viewModels = self?.viewModels,
                        let settings = self?.settings,
                        !settings.cardsSwipeHintWasShown,
                        viewModels.count > 1 {
                        self?.view.showSwipeLeftRightHint()
                        self?.settings.cardsSwipeHintWasShown = true
                    }
                }
                self?.startObservingWebTagsData()
            case .error(let error):
                self?.errorPresenter.present(error: error)
            }
        })
    }

    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviTagReactor.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.didLoadInitialRuuviTags = true
                self?.ruuviTags = ruuviTags.map({ $0.any })
                if let firstTag = ruuviTags.first {
                    self?.tagCharts?.configure(ruuviTag: firstTag)
                    self?.restartObservingRuuviTagNetwork(for: firstTag)
                }
                self?.syncViewModels()
                self?.startListeningToRuuviTagsAlertStatus()
                self?.observeRuuviTags()
            case .insert(let sensor):
                self?.ruuviTags.append(sensor.any)
                self?.syncViewModels()
                self?.startListeningToRuuviTagsAlertStatus()
                self?.observeRuuviTags()
                if let index = self?.viewModels.firstIndex(where: { $0.luid.value == sensor.luid?.any }) {
                    self?.view.scroll(to: index)
                    self?.restartObservingRuuviTagNetwork(for: sensor)
                    self?.tagCharts?.configure(ruuviTag: sensor)
                    if let viewModels = self?.viewModels,
                        let settings = self?.settings,
                        !settings.cardsSwipeHintWasShown,
                        viewModels.count > 1 {
                        self?.view.showSwipeLeftRightHint()
                        self?.settings.cardsSwipeHintWasShown = true
                    }
                }
            case .delete(let sensor):
                self?.ruuviTags.removeAll(where: { $0.id == sensor.id })
                if let last = self?.ruuviTags.last {
                    self?.tagCharts?.configure(ruuviTag: last)
                }
                self?.syncViewModels()
                self?.startListeningToRuuviTagsAlertStatus()
                self?.observeRuuviTags()
                if let currentPage = self?.view.currentPage,
                    let tagsCount = self?.ruuviTags.count,
                    currentPage < tagsCount,
                    let tag = self?.ruuviTags[currentPage] {
                    self?.restartObservingRuuviTagNetwork(for: tag)
                } else {
                    self?.ruuviTagObserveLastRecordToken?.invalidate()
                }
            case .error(let error):
                self?.errorPresenter.present(error: error)
            case .update(let sensor):
                guard let sSelf = self else { return }
                if let index = sSelf.ruuviTags.firstIndex(of: sensor) {
                    sSelf.ruuviTags[index] = sensor
                    sSelf.syncViewModels()
                }
            }
        }
    }

    private func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter
            .default
            .addObserver(forName: .BackgroundPersistenceDidChangeBackground,
                         object: nil,
                         queue: .main) { [weak self] notification in
            if let userInfo = notification.userInfo,
                let luid = userInfo[BPDidChangeBackgroundKey.luid] as? LocalIdentifier,
                let viewModel = self?.view.viewModels.first(where: { $0.luid.value == luid.any }) {
                    viewModel.background.value = self?.backgroundPersistence.background(for: luid)
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func startObservingDaemonsErrors() {
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
                } else if case .parse(let parseError) = error, parseError == OWMError.apiLimitExceeded {
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
        startKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(forName: .ConnectionPersistenceDidStartToKeepConnection,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
            self?.observeRuuviTagHeartbeats()
            self?.observeRuuviTagRSSI()
        })

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
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String {
                self?.viewModels.filter({ $0.luid.value == uuid.luid.any }).forEach({ (viewModel) in
                    self?.updateAlertState(for: viewModel)
                })
            }
        })
    }

    private func startObservingCalibrationHumidityChanges() {
        calibrationHumidityDidChangeToken = NotificationCenter
                   .default
                   .addObserver(forName: .CalibrationServiceHumidityDidChange,
                                object: nil,
                                queue: .main,
                                using: { [weak self] (notification) in
                   if let userInfo = notification.userInfo,
                       let luid = userInfo[CalibrationServiceHumidityDidChangeKey.luid] as? LocalIdentifier {
                       self?.viewModels.filter({ $0.luid.value == luid.any }).forEach({ (viewModel) in
                        viewModel.humidityOffset.value = self?.calibrationService.humidityOffset(for: luid).0
                        viewModel.humidityOffsetDate.value = self?.calibrationService.humidityOffset(for: luid).1
                       })
                   }
               })
    }

    private func startObserveMigrationCompletion() {
        didMigrationCompleteToken = NotificationCenter
            .default
            .addObserver(forName: .DidMigrationComplete, object: nil, queue: .main, using: { [weak self] (_) in
                self?.startObservingRuuviTags()
            })
    }

    private func updateAlertState(for viewModel: CardsViewModel) {
        if let uuid = viewModel.luid.value {
            var newValue: AlertState
            if alertService.hasRegistrations(for: uuid.value) {
                var isTriggered = false
                AlertType.allCases.forEach { type in
                    switch type {
                    case .temperature:
                        isTriggered = isTriggered || isTriggering(temperature: type, for: viewModel)
                    case .relativeHumidity:
                        isTriggered = isTriggered || isTriggering(relativeHumidity: type, for: viewModel)
                    case .absoluteHumidity:
                        isTriggered = isTriggered || isTriggering(absoluteHumidity: type, for: viewModel)
                    case .dewPoint:
                        isTriggered = isTriggered || isTriggering(dewPoint: type, for: viewModel)
                    case .pressure:
                        isTriggered = isTriggered || isTriggering(pressure: type, for: viewModel)
                    default:
                        break
                    }
                }
                newValue = isTriggered ? .firing : .registered
            } else {
                newValue = .empty
            }
            if newValue != viewModel.alertState.value {
                viewModel.alertState.value = newValue
            }
        }
    }

    private func isTriggering(temperature: AlertType, for viewModel: CardsViewModel) -> Bool {
        if let luid = viewModel.luid.value,
            case .temperature(let lower, let upper) = alertService.alert(for: luid.value, of: temperature),
            let celsius = viewModel.celsius.value {
            let isLower = celsius < lower
            let isUpper = celsius > upper
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func isTriggering(relativeHumidity: AlertType, for viewModel: CardsViewModel) -> Bool {
        if let luid = viewModel.luid.value,
            case .relativeHumidity(let lower, let upper) = alertService.alert(for: luid.value, of: relativeHumidity),
            let rh = viewModel.relativeHumidity.value {
            let ho = calibrationService.humidityOffset(for: luid).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let isLower = sh < lower
            let isUpper = sh > upper
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func isTriggering(absoluteHumidity: AlertType, for viewModel: CardsViewModel) -> Bool {
        if let luid = viewModel.luid.value,
            case .absoluteHumidity(let lower, let upper) = alertService.alert(for: luid.value, of: absoluteHumidity),
            let rh = viewModel.relativeHumidity.value,
            let c = viewModel.celsius.value {
            let ho = calibrationService.humidityOffset(for: luid).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let h = Humidity(c: c, rh: sh / 100.0)
            let ah = h.ah

            let isLower = ah < lower
            let isUpper = ah > upper
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func isTriggering(dewPoint: AlertType, for viewModel: CardsViewModel) -> Bool {
        if let luid = viewModel.luid.value,
            case .dewPoint(let lower, let upper) = alertService.alert(for: luid.value, of: dewPoint),
            let rh = viewModel.relativeHumidity.value,
            let c = viewModel.celsius.value {
            let ho = calibrationService.humidityOffset(for: luid).0
            var sh = rh + ho
            if sh > 100.0 {
                sh = 100.0
            }
            let h = Humidity(c: c, rh: sh / 100.0)
            if let hTd = h.Td {
                let isLower = hTd < lower
                let isUpper = hTd > upper
                return isLower || isUpper
            } else {
                return false
            }
        } else {
            return false
        }
    }

    private func isTriggering(pressure: AlertType, for viewModel: CardsViewModel) -> Bool {
        if let luid = viewModel.luid.value,
            case .pressure(let lower, let upper) = alertService.alert(for: luid.value, of: pressure),
            let pressure = viewModel.pressure.value {
            let isLower = pressure < lower
            let isUpper = pressure > upper
            return isLower || isUpper
        } else {
            return false
        }
    }

    private func startListeningToRuuviTagsAlertStatus() {
        ruuviTags.forEach({ alertService.subscribe(self, to: $0.id) })
    }

    private func startListeningToWebTagsAlertStatus() {
        virtualTags?.forEach({ alertService.subscribe(self, to: $0.uuid) })
    }

    private func startObservingLocalNotificationsManager() {
        lnmDidReceiveToken = NotificationCenter
            .default
            .addObserver(forName: .LNMDidReceive,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let uuid = notification.userInfo?[LNMDidReceiveKey.uuid] as? String,
                let index = self?.viewModels.firstIndex(where: { $0.luid.value == uuid.luid.any }),
                let ruuviTag = self?.ruuviTags.first(where: {$0.luid?.value == uuid}) {
                self?.view.scroll(to: index)
                self?.tagCharts?.configure(ruuviTag: ruuviTag)
            }
        })
    }
}
// swiftlint:enable file_length
