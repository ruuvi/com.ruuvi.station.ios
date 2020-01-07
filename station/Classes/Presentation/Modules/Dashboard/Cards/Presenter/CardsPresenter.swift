// swiftlint:disable file_length
import Foundation
import RealmSwift
import BTKit

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

    weak var tagCharts: TagChartsModuleInput?

    private var ruuviTagsToken: NotificationToken?
    private var webTagsToken: NotificationToken?
    private var webTagsDataTokens = [NotificationToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var rssiTokens = [String: ObservationToken]()
    private var rssiTimers = [String: Timer]()
    private var temperatureUnitToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var webTagDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagAdvertisementDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagPropertiesDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagConnectionDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagHeartbeatDaemonFailureToken: NSObjectProtocol?
    private var ruuviTagReadLogsOperationFailureToken: NSObjectProtocol?
    private var startKeepingConnectionToken: NSObjectProtocol?
    private var stopKeepingConnectionToken: NSObjectProtocol?
    private var readRSSIToken: NSObjectProtocol?
    private var readRSSIIntervalToken: NSObjectProtocol?
    private var didConnectToken: NSObjectProtocol?
    private var didDisconnectToken: NSObjectProtocol?
    private var temperatureAlertDidChangeToken: NSObjectProtocol?
    private var stateToken: ObservationToken?
    private var webTags: Results<WebTagRealm>? {
        didSet {
            syncViewModels()
        }
    }
    private var ruuviTags: Results<RuuviTagRealm>? {
        didSet {
            syncViewModels()
            startListeningToAlertStatus()
        }
    }
    private var viewModels = [CardsViewModel]() {
        didSet {
            view.viewModels = viewModels
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    deinit {
        ruuviTagsToken?.invalidate()
        webTagsToken?.invalidate()
        rssiTokens.values.forEach({ $0.invalidate() })
        rssiTimers.values.forEach({ $0.invalidate() })
        advertisementTokens.forEach({ $0.invalidate() })
        heartbeatTokens.forEach({ $0.invalidate() })
        webTagsDataTokens.forEach({ $0.invalidate() })
        stateToken?.invalidate()
        if let temperatureUnitToken = temperatureUnitToken {
            NotificationCenter.default.removeObserver(temperatureUnitToken)
        }
        if let humidityUnitToken = humidityUnitToken {
            NotificationCenter.default.removeObserver(humidityUnitToken)
        }
        if let backgroundToken = backgroundToken {
            NotificationCenter.default.removeObserver(backgroundToken)
        }
        if let webTagDaemonFailureToken = webTagDaemonFailureToken {
            NotificationCenter.default.removeObserver(webTagDaemonFailureToken)
        }
        if let ruuviTagAdvertisementDaemonFailureToken = ruuviTagAdvertisementDaemonFailureToken {
            NotificationCenter.default.removeObserver(ruuviTagAdvertisementDaemonFailureToken)
        }
        if let ruuviTagConnectionDaemonFailureToken = ruuviTagConnectionDaemonFailureToken {
            NotificationCenter.default.removeObserver(ruuviTagConnectionDaemonFailureToken)
        }
        if let ruuviTagHeartbeatDaemonFailureToken = ruuviTagHeartbeatDaemonFailureToken {
            NotificationCenter.default.removeObserver(ruuviTagHeartbeatDaemonFailureToken)
        }
        if let ruuviTagReadLogsOperationFailureToken = ruuviTagReadLogsOperationFailureToken {
            NotificationCenter.default.removeObserver(ruuviTagReadLogsOperationFailureToken)
        }
        if let startKeepingConnectionToken = startKeepingConnectionToken {
            NotificationCenter.default.removeObserver(startKeepingConnectionToken)
        }
        if let stopKeepingConnectionToken = stopKeepingConnectionToken {
            NotificationCenter.default.removeObserver(stopKeepingConnectionToken)
        }
        if let ruuviTagPropertiesDaemonFailureToken = ruuviTagPropertiesDaemonFailureToken {
            NotificationCenter.default.removeObserver(ruuviTagPropertiesDaemonFailureToken)
        }
        if let didConnectToken = didConnectToken {
            NotificationCenter.default.removeObserver(didConnectToken)
        }
        if let didDisconnectToken = didDisconnectToken {
            NotificationCenter.default.removeObserver(didDisconnectToken)
        }
        if let temperatureAlertDidChangeToken = temperatureAlertDidChangeToken {
            NotificationCenter.default.removeObserver(temperatureAlertDidChangeToken)
        }
        if let readRSSIToken = readRSSIToken {
            NotificationCenter.default.removeObserver(readRSSIToken)
        }
        if let readRSSIIntervalToken = readRSSIIntervalToken {
            NotificationCenter.default.removeObserver(readRSSIIntervalToken)
        }
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
        if viewModel.type == .ruuvi, let ruuviTag = ruuviTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
            router.openTagSettings(ruuviTag: ruuviTag, humidity: viewModel.relativeHumidity.value)
        } else if viewModel.type == .web, let webTag = webTags?.first(where: { $0.uuid == viewModel.uuid.value }) {
            router.openWebTagSettings(webTag: webTag)
        }
    }

    func viewDidTriggerChart(for viewModel: CardsViewModel) {
        if let uuid = viewModel.uuid.value {
            if settings.keepConnectionDialogWasShown(for: uuid)
                || background.isConnected(uuid: uuid) {
                router.openTagCharts()
            } else {
                view.showKeepConnectionDialog(for: viewModel)
            }
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialog(for viewModel: CardsViewModel) {
        if let uuid = viewModel.uuid.value {
            settings.setKeepConnectionDialogWasShown(for: uuid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnection(to viewModel: CardsViewModel) {
        if let uuid = viewModel.uuid.value {
            connectionPersistence.setKeepConnection(true, for: uuid)
            settings.setKeepConnectionDialogWasShown(for: uuid)
            router.openTagCharts()
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidScroll(to viewModel: CardsViewModel) {
        if let uuid = viewModel.uuid.value {
            tagCharts?.configure(uuid: uuid)
        } else {
            assert(false)
        }
    }
}

// MARK: - DiscoverModuleOutput
extension CardsPresenter: DiscoverModuleOutput {
    func discover(module: DiscoverModuleInput, didAdd ruuviTag: RuuviTag) {
        module.dismiss()
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
        mailComposerPresenter.present(email: feedbackEmail, subject: feedbackSubject)
    }
}

// MARK: - TagChartsModuleOutput
extension CardsPresenter: TagChartsModuleOutput {
    func tagCharts(module: TagChartsModuleInput, didScrollTo uuid: String) {
        if let index = viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
            view.scroll(to: index, immediately: true)
        }
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
            .filter({ $0.uuid.value == uuid })
            .forEach({ $0.alertState.value = isTriggered ? .firing : .registered })
    }
}

// MARK: - Private
extension CardsPresenter {

    private func syncViewModels() {
        if ruuviTags != nil && webTags != nil {
            let ruuviViewModels = ruuviTags?.compactMap({ (ruuviTag) -> CardsViewModel in
                let viewModel = CardsViewModel(ruuviTag)
                viewModel.humidityUnit.value = settings.humidityUnit
                viewModel.background.value = backgroundPersistence.background(for: ruuviTag.uuid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.isConnected.value = background.isConnected(uuid: ruuviTag.uuid)
                viewModel.alertState.value = alertService.hasRegistrations(for: ruuviTag.uuid) ? .registered : .empty
                return viewModel
            }) ?? []
            let webViewModels = webTags?.compactMap({ (webTag) -> CardsViewModel in
                let viewModel = CardsViewModel(webTag)
                viewModel.humidityUnit.value = settings.humidityUnit
                viewModel.background.value = backgroundPersistence.background(for: webTag.uuid)
                viewModel.temperatureUnit.value = settings.temperatureUnit
                viewModel.alertState.value = alertService.hasRegistrations(for: webTag.uuid) ? .registered : .empty
                viewModel.isConnected.value = false
                return viewModel
            }) ?? []
            viewModels = ruuviViewModels + webViewModels

            // if no tags, open discover
            if viewModels.count == 0 {
                router.openDiscover(output: self)
            }
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
            .filter({ (uuid) -> Bool in
                ruuviTags?.contains(where: { $0.uuid == uuid }) ?? false
            }).forEach { (uuid) in
                if settings.readRSSI {
                    let interval = settings.readRSSIIntervalSeconds
                    let timer = Timer
                        .scheduledTimer(withTimeInterval: TimeInterval(interval),
                                        repeats: true) { [weak self] timer in
                        guard let sSelf = self else { timer.invalidate(); return }
                        sSelf.rssiTokens[uuid] = sSelf
                            .background
                            .readRSSI(for: sSelf,
                                      uuid: uuid,
                                      result: { (observer, result) in
                            switch result {
                            case .success(let rssi):
                                if let viewModel = observer.viewModels.first(where: { $0.uuid.value == uuid }) {
                                    viewModel.update(rssi: rssi, animated: true)
                                }
                            case .failure(let error):
                                switch error {
                                case .logic(let logicError):
                                    switch logicError {
                                    case .notConnected:
                                        break // do nothing
                                    default:
                                        observer.errorPresenter.present(error: error)
                                    }
                                default:
                                    observer.errorPresenter.present(error: error)
                                }
                            }
                        })
                    }
                    timer.fire()
                    rssiTimers[uuid] = timer
                }
            }
    }

    private func observeRuuviTagHeartbeats() {
        heartbeatTokens.forEach({ $0.invalidate() })
        heartbeatTokens.removeAll()
        connectionPersistence.keepConnectionUUIDs.filter { (uuid) -> Bool in
            ruuviTags?.contains(where: { $0.uuid == uuid }) ?? false
        }.forEach { (uuid) in
            heartbeatTokens.append(background.observe(self, uuid: uuid) { [weak self] (_, device) in
                if let ruuviTag = device.ruuvi?.tag,
                    let viewModel = self?.viewModels.first(where: { $0.uuid.value == ruuviTag.uuid }) {
                    viewModel.update(with: ruuviTag)
                }
            })
        }
    }

    private func observeRuuviTagAdvertisements() {
        advertisementTokens.forEach({ $0.invalidate() })
        advertisementTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi, let uuid = viewModel.uuid.value {
                advertisementTokens.append(foreground.observe(self, uuid: uuid) { [weak self] (_, device) in
                    if let ruuviTag = device.ruuvi?.tag,
                        let viewModel = self?.viewModels.first(where: { $0.uuid.value == ruuviTag.uuid }) {
                        viewModel.update(with: ruuviTag)
                        viewModel.update(rssi: ruuviTag.rssi)
                    }
                })
            }
        }
    }

    private func startObservingWebTagsData() {
        webTagsDataTokens.forEach({ $0.invalidate() })
        webTagsDataTokens.removeAll()

        webTags?.forEach({ webTag in
            webTagsDataTokens.append(webTag.data.observe { [weak self] (change) in
                switch change {
                case .initial(let data):
                    if let last = data.sorted(byKeyPath: "date").last {
                        self?.viewModels
                            .filter({ $0.uuid.value == webTag.uuid })
                            .forEach({ $0.update(last)})
                    }
                case .update(let data, _, _, _):
                    if let last = data.sorted(byKeyPath: "date").last {
                        self?.viewModels
                            .filter({ $0.uuid.value == webTag.uuid })
                            .forEach({ $0.update(last)})
                    }
                case .error(let error):
                    self?.errorPresenter.present(error: error)
                }
            })
        })
    }

    private func startObservingWebTags() {
        webTags = realmContext.main.objects(WebTagRealm.self)
        webTagsToken = webTags?.observe({ [weak self] (change) in
            switch change {
            case .initial(let webTags):
                self?.webTags = webTags
                self?.startObservingWebTagsData()
            case .update(let webTags, _, let insertions, _):
                self?.webTags = webTags
                if let ii = insertions.last {
                    let uuid = webTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                        self?.tagCharts?.configure(uuid: uuid)
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
        ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        ruuviTagsToken?.invalidate()
        ruuviTagsToken = ruuviTags?.observe { [weak self] (change) in
            switch change {
            case .initial(let ruuviTags):
                self?.ruuviTags = ruuviTags
                self?.observeRuuviTags()
            case .update(let ruuviTags, _, let insertions, _):
                self?.ruuviTags = ruuviTags
                if let ii = insertions.last {
                    let uuid = ruuviTags[ii].uuid
                    if let index = self?.viewModels.firstIndex(where: { $0.uuid.value == uuid }) {
                        self?.view.scroll(to: index)
                        self?.tagCharts?.configure(uuid: uuid)
                    }
                    if let viewModels = self?.viewModels,
                        let settings = self?.settings,
                        !settings.cardsSwipeHintWasShown,
                        viewModels.count > 1 {
                        self?.view.showSwipeLeftRightHint()
                        self?.settings.cardsSwipeHintWasShown = true
                    }
                }
                self?.observeRuuviTags()
            case .error(let error):
                self?.errorPresenter.present(error: error)
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
                let uuid = userInfo[BPDidChangeBackgroundKey.uuid] as? String,
                let viewModel = self?.view.viewModels.first(where: { $0.uuid.value == uuid }) {
                    viewModel.background.value = self?.backgroundPersistence.background(for: uuid)
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

        ruuviTagConnectionDaemonFailureToken = NotificationCenter
            .default
            .addObserver(forName: .RuuviTagConnectionDaemonDidFail,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let userInfo = notification.userInfo,
                let error = userInfo[RuuviTagConnectionDaemonDidFailKey.error] as? RUError {
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
                let viewModel = self?.viewModels.first(where: { $0.uuid.value == uuid }) {
                viewModel.isConnected.value = true
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
                let viewModel = self?.viewModels.first(where: { $0.uuid.value == uuid }) {
                viewModel.isConnected.value = false
            }
        })
    }

    private func startObservingAlertChanges() {
        temperatureAlertDidChangeToken = NotificationCenter
            .default
            .addObserver(forName: .AlertServiceAlertDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
            if let sSelf = self,
                let userInfo = notification.userInfo,
                let uuid = userInfo[AlertServiceAlertDidChangeKey.uuid] as? String {
                sSelf.viewModels.filter({ $0.uuid.value == uuid }).forEach({ (viewModel) in
                    viewModel.alertState.value = sSelf.alertService.hasRegistrations(for: uuid) ? .registered : .empty
                })
            }
        })
    }

    private func startListeningToAlertStatus() {
        ruuviTags?.forEach({ alertService.subscribe(self, to: $0.uuid) })
    }
}
// swiftlint:enable file_length
