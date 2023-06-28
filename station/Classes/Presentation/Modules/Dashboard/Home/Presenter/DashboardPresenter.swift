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
import WidgetKit
import CoreBluetooth
import Future

class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput?
    var router: DashboardRouterInput!
    var interactor: DashboardInteractorInput!
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
    var cloudSyncDaemon: RuuviDaemonCloudSync!
    var ruuviAppSettingsService: RuuviServiceAppSettings!
    var authService: RuuviServiceAuth!
    var activityPresenter: ActivityPresenter!
    var pnManager: RuuviCorePN!
    var cloudNotificationService: RuuviServiceCloudNotification!
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordTokens = [RuuviReactorToken]()
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
    private var universalLinkObservationToken: NSObjectProtocol?
    private var cloudModeToken: NSObjectProtocol?
    private var temperatureUnitToken: NSObjectProtocol?
    private var temperatureAccuracyToken: NSObjectProtocol?
    private var humidityUnitToken: NSObjectProtocol?
    private var humidityAccuracyToken: NSObjectProtocol?
    private var pressureUnitToken: NSObjectProtocol?
    private var pressureAccuracyToken: NSObjectProtocol?
    private var languageToken: NSObjectProtocol?
    private var systemLanguageChangeToken: NSObjectProtocol?
    private var calibrationSettingsToken: NSObjectProtocol?
    private var dashboardTypeToken: NSObjectProtocol?
    private var dashboardTapActionTypeToken: NSObjectProtocol?
    private var cloudSyncToken: NSObjectProtocol?
    private var virtualSensors = [AnyVirtualTagSensor]() {
        didSet {
            startListeningToWebTagsAlertStatus()
        }
    }
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var viewModels: [CardsViewModel] = [] {
        didSet {
            view?.viewModels = viewModels
        }
    }
    private var didLoadInitialRuuviTags = false
    private var didLoadInitialWebTags = false
    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )
    private var isBluetoothPermissionGranted: Bool {
        return CBCentralManager.authorization == .allowedAlways
    }
    
    deinit {
        ruuviTagToken?.invalidate()
        virtualSensorsToken?.invalidate()
        ruuviTagObserveLastRecordTokens.forEach({ $0.invalidate() })
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
        universalLinkObservationToken?.invalidate()
        cloudModeToken?.invalidate()
        temperatureUnitToken?.invalidate()
        temperatureAccuracyToken?.invalidate()
        humidityUnitToken?.invalidate()
        humidityAccuracyToken?.invalidate()
        pressureUnitToken?.invalidate()
        pressureAccuracyToken?.invalidate()
        languageToken?.invalidate()
        systemLanguageChangeToken?.invalidate()
        calibrationSettingsToken?.invalidate()
        dashboardTypeToken?.invalidate()
        dashboardTapActionTypeToken?.invalidate()
        cloudSyncToken?.invalidate()
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
}

// MARK: - DashboardViewOutput
extension DashboardPresenter: DashboardViewOutput {
    func viewDidLoad() {
        startObservingRuuviTags()
        startObservingWebTags()
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingConnectionPersistenceNotifications()
        startObservingDidConnectDisconnectNotifications()
        startObservingAlertChanges()
        startObservingCloudModeNotification()
        startListeningToSettings()
        startObserveCalibrationSettingsChange()
        startObservingCloudSyncTokenState()
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

    func viewDidTriggerBuySensors() {
        router.openRuuviProductsPage()
    }

    func viewDidTriggerSettings(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid.value {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || !viewModel.isConnectable.value.bound
                    || !viewModel.isOwner.value.bound
                    || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                    openTagSettingsScreens(viewModel: viewModel)
                } else {
                    view?.showKeepConnectionDialogSettings(for: viewModel)
                }
            } else {
                openTagSettingsScreens(viewModel: viewModel)
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
                || !viewModel.isConnectable.value.bound
                || !viewModel.isOwner.value.bound
                || (settings.cloudModeEnabled && viewModel.isCloud.value.bound) {
                openCardView(viewModel: viewModel, showCharts: true)
            } else {
                view?.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac.value != nil {
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerOpenCardImageView(for viewModel: CardsViewModel?) {
        guard let viewModel = viewModel else { return }
        openCardView(viewModel: viewModel, showCharts: false)
    }

    // swiftlint:disable switch_case_alignment
    func viewDidTriggerDashboardCard(for viewModel: CardsViewModel) {
        switch settings.dashboardTapActionType {
            case .card:
                viewDidTriggerOpenCardImageView(for: viewModel)
            case .chart:
                viewDidTriggerChart(for: viewModel)
        }
    }
    // swiftlint:enable switch_case_alignment

    func viewDidTriggerChangeBackground(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                router.openBackgroundSelectionView(ruuviTag: ruuviTagSensor)
            }
        } else if viewModel.type == .web,
                  let webTag = virtualSensors.first(where: { $0.id == viewModel.id.value }) {
            router.openBackgroundSelectionView(virtualSensor: webTag)
        }
        
    }
    
    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid.value {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidChangeDashboardType(dashboardType: DashboardType) {
        if settings.dashboardType == dashboardType {
            return
        }

        view?.dashboardType = dashboardType
        settings.dashboardType = dashboardType
        ruuviAppSettingsService.set(dashboardType: dashboardType)
    }

    func viewDidChangeDashboardTapAction(type: DashboardTapActionType) {
        settings.dashboardTapActionType = type
        view?.dashboardTapActionType = type
        ruuviAppSettingsService.set(dashboardTapActionType: type)
    }
}

// MARK: - MenuModuleOutput
extension DashboardPresenter: MenuModuleOutput {
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

    func menu(module: MenuModuleInput, didSelectWhatToMeasure sender: Any?) {
        module.dismiss()
        router.openWhatToMeasurePage()
    }
    
    func menu(module: MenuModuleInput, didSelectGetMoreSensors sender: Any?) {
        module.dismiss()
        router.openRuuviProductsPageFromMenu()
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
    
    func menu(module: MenuModuleInput, didSelectOpenMyRuuviAccount sender: Any?) {
        module.dismiss()
        router.openMyRuuviAccount()
    }
}

// MARK: - SignInBenefitsModuleOutput
extension DashboardPresenter: SignInBenefitsModuleOutput {
    func signIn(module: SignInBenefitsModuleInput,
                didSuccessfulyLogin sender: Any?) {
        startObservingRuuviTags()
        startObservingCloudModeNotification()
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }

    func signIn(module: SignInBenefitsModuleInput,
                didCloseSignInWithoutAttempt sender: Any?) {
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }

    func signIn(module: SignInBenefitsModuleInput,
                didSelectUseWithoutAccount sender: Any?) {
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }
}

// MARK: - DashboardRouterDelegate
extension DashboardPresenter: DashboardRouterDelegate {
    func shouldDismissDiscover() -> Bool {
        return viewModels.count > 0
    }
}

// MARK: - RuuviNotifierObserver
extension DashboardPresenter: RuuviNotifierObserver {
    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        // No op here.
    }

    func ruuvi(notifier: RuuviNotifier,
               alertType: AlertType,
               isTriggered: Bool,
               for uuid: String) {

        viewModels
            .filter({ $0.luid.value?.value == uuid ||  $0.mac.value?.value == uuid})
            .forEach({ viewModel in
                let isFireable = viewModel.isCloud.value ?? false ||
                        viewModel.isConnected.value ?? false
                switch alertType {
                case .temperature:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.temperatureAlertState.value = newValue
                case .relativeHumidity:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.relativeHumidityAlertState.value = newValue
                case .pressure:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pressureAlertState.value = newValue
                case .signal:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.signalAlertState.value = newValue
                case .connection:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.connectionAlertState.value = newValue
                case .movement:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.movementAlertState.value = newValue
                default:
                    break
                }
                let alertStates = [
                    viewModel.temperatureAlertState.value,
                    viewModel.relativeHumidityAlertState.value,
                    viewModel.pressureAlertState.value,
                    viewModel.signalAlertState.value,
                    viewModel.connectionAlertState.value,
                    viewModel.movementAlertState.value
                ]
                if alertStates.first(where: { alert in
                    alert == .firing
                }) != nil {
                    viewModel.alertState.value = .firing
                } else {
                    viewModel.alertState.value = .registered
                }

                notifyViewModelUpdate(for: viewModel)
            })
    }
}

// MARK: - CardsModuleOutput
extension DashboardPresenter: CardsModuleOutput {
    func cardsViewDidDismiss(module: CardsModuleInput) {
        module.dismiss(completion: nil)
    }

    func cardsViewDidRefresh(module: CardsModuleInput) {
        // No op.
    }
}

// MARK: - TagSettingsModuleOutput
extension DashboardPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput,
                                 ruuviTag: RuuviTagSensor) {
        module.dismiss(completion: { [weak self] in
            self?.startObservingRuuviTags()
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Private
extension DashboardPresenter {

    // swiftlint:disable:next function_body_length
    private func syncViewModels() {

        view?.dashboardType = settings.dashboardType
        view?.dashboardTapActionType = settings.dashboardTapActionType

        let ruuviViewModels = ruuviTags.compactMap({ (ruuviTag) -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: {[weak self] image in
                    viewModel.background.value = image
                    self?.notifyViewModelUpdate(for: viewModel)
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
            viewModel.rhAlertLowerBound.value = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound.value = alertService
                .upperRelativeHumidity(for: ruuviTag)
            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record = record {
                    viewModel.update(record)
                    self?.notifyViewModelUpdate(for: viewModel)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            return viewModel
        })
        let virtualViewModels = virtualSensors.compactMap({ virtualSensor -> CardsViewModel in
            let viewModel = CardsViewModel(virtualSensor)
            ruuviSensorPropertiesService.getImage(for: virtualSensor)
                .on(success: { [weak self] image in
                    viewModel.background.value = image
                    self?.notifyViewModelUpdate(for: viewModel)
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            viewModel.alertState.value = alertService
                .hasRegistrations(for: virtualSensor) ? .registered : .empty
            viewModel.isConnected.value = false
            notifyViewModelUpdate(for: viewModel)
            return viewModel
        })

        let vms = reorder(ruuviViewModels + virtualViewModels)
        if didLoadInitialRuuviTags
            && didLoadInitialWebTags {
            view?.showNoSensorsAddedMessage(show: vms.isEmpty)
            askAppStoreReview(with: vms.count)
        }

        if !vms.isEmpty {
            self.viewModels = vms
        }
    }

    private func syncViewModel(ruuviTagSensor: RuuviTagSensor?,
                               virtualSensor: VirtualTagSensor?) {
        if let ruuviTag = ruuviTagSensor {
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: {[weak self] image in
                    viewModel.background.value = image
                    self?.notifyViewModelUpdate(for: viewModel)
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
            viewModel.rhAlertLowerBound.value = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound.value = alertService
                .upperRelativeHumidity(for: ruuviTag)
            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record = record {
                    viewModel.update(record)
                    self?.notifyViewModelUpdate(for: viewModel)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            viewModels.append(viewModel)
            viewModels = reorder(viewModels)
        }

        if let virtualSensor = virtualSensor {
            let viewModel = CardsViewModel(virtualSensor)
            ruuviSensorPropertiesService.getImage(for: virtualSensor)
                .on(success: { [weak self] image in
                    viewModel.background.value = image
                    self?.notifyViewModelUpdate(for: viewModel)
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            viewModel.alertState.value = alertService.hasRegistrations(for: virtualSensor) ? .registered : .empty
            viewModel.isConnected.value = false

            viewModels.append(viewModel)
            viewModels = reorder(viewModels)
        }
    }

    private func processAlert(record: RuuviTagSensorRecord,
                              viewModel: CardsViewModel) {
        if let isCloud = viewModel.isCloud.value,
           isCloud && settings.cloudModeEnabled,
            let macId = viewModel.mac.value {
            alertHandler.processNetwork(record: record,
                                        trigger: false,
                                        for: macId)
        } else {
            if viewModel.luid.value != nil {
                alertHandler.process(record: record, trigger: false)
            } else {
                guard let macId = viewModel.mac.value else {
                    return
                }
                alertHandler.processNetwork(record: record, trigger: false, for: macId)
            }
        }
    }

    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        let sortedAndUniqueArray = viewModels.reduce(
            into: [CardsViewModel]()
        ) { (result, element) in
            if !result.contains(element) {
                // Insert the element into the result array while maintaining the sorted order
                if let index = result.firstIndex(
                    where: {
                        $0.name.value?.lowercased() ?? "" >
                        element.name.value?.lowercased() ?? "" }
                ) {
                    result.insert(element, at: index)
                } else {
                    // If no such index is found, append the element at the end
                    result.append(element)
                }
            }
        }
        return sortedAndUniqueArray
    }

    private func syncAppSettingsToAppGroupContainer() {
        appGroupDefaults?.set(
            ruuviUser.isAuthorized,
            forKey: AppGroupConstants.isAuthorizedUDKey
        )

        // Temperature
        var temperatureUnitInt: Int = 2
        switch settings.temperatureUnit {
        case .kelvin:
            temperatureUnitInt = 1
        case .celsius:
            temperatureUnitInt = 2
        case .fahrenheit:
            temperatureUnitInt = 3
        }
        appGroupDefaults?.set(
            temperatureUnitInt,
            forKey: AppGroupConstants.temperatureUnitKey
        )

        appGroupDefaults?.set(
            settings.temperatureAccuracy.value,
            forKey: AppGroupConstants.temperatureAccuracyKey
        )

        // Humidity
        var humidityUnitInt: Int = 0
        switch settings.humidityUnit {
        case .percent:
            humidityUnitInt = 0
        case .gm3:
            humidityUnitInt = 1
        case .dew:
            humidityUnitInt = 2
        }
        appGroupDefaults?.set(
            humidityUnitInt,
            forKey: AppGroupConstants.humidityUnitKey
        )

        appGroupDefaults?.set(
            settings.humidityAccuracy.value,
            forKey: AppGroupConstants.humidityAccuracyKey)

        // Pressure
        appGroupDefaults?.set(
            settings.pressureUnit.hashValue,
            forKey: AppGroupConstants.pressureUnitKey
        )

        appGroupDefaults?.set(
            settings.pressureAccuracy.value,
            forKey: AppGroupConstants.pressureAccuracyKey
        )

        // Reload widget
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }

    private func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { (observer, state) in
            if state != .poweredOn || !self.isBluetoothPermissionGranted {
                observer.view?.showBluetoothDisabled(
                    userDeclined: !self.isBluetoothPermissionGranted
                )
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
            ruuviTags.filter({ !(settings.cloudModeEnabled && $0.isCloud) && $0.isOwner })
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
                    let record = ruuviTag
                        .with(source: .heartbeat)
                        .with(sensorSettings: sensorSettings)
                    viewModel.update(
                        record
                    )
                    self?.notifyViewModelUpdate(for: viewModel)
                    self?.alertHandler.process(record: record, trigger: false)
                }
            })
        }
    }

    private func restartObserveRuuviTagAdvertisements() {
        advertisementTokens.forEach({ $0.invalidate() })
        advertisementTokens.removeAll()
        for viewModel in viewModels {
            let shouldAvoidObserving =
                ruuviUser.isAuthorized &&
                settings.cloudModeEnabled &&
                viewModel.isCloud.value.bound
            if shouldAvoidObserving {
                continue
            }
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
                        self?.notifyViewModelUpdate(for: viewModel)
                        self?.alertHandler.process(record: record, trigger: false)
                    }
                })
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach({ $0.invalidate() })
        sensorSettingsTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor, { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case .insert(let sensorSettings):
                            self?.sensorSettingsList.append(sensorSettings)
                            if let viewModel = sSelf.viewModels.first(where: {
                                $0.id.value == ruuviTagSensor.id
                            }) {
                                self?.notifySensorSettingsUpdate(
                                    sensorSettings: sensorSettings,
                                    viewModel: viewModel
                                )
                            }
                        case .update(let updateSensorSettings):
                            if let updateIndex = self?.sensorSettingsList.firstIndex(
                                where: { $0.id == updateSensorSettings.id }
                            ) {
                                self?.sensorSettingsList[updateIndex] = updateSensorSettings
                                if let viewModel = sSelf.viewModels.first(where: {
                                    $0.id.value == ruuviTagSensor.id
                                }) {
                                    self?.notifySensorSettingsUpdate(
                                        sensorSettings: updateSensorSettings,
                                        viewModel: viewModel
                                    )
                                }
                            } else {
                                self?.sensorSettingsList.append(updateSensorSettings)
                            }
                        case .delete(let deleteSensorSettings):
                            if let deleteIndex = self?.sensorSettingsList.firstIndex(
                                where: { $0.id == deleteSensorSettings.id }
                            ) {
                                self?.sensorSettingsList.remove(at: deleteIndex)
                                if let viewModel = sSelf.viewModels.first(where: {
                                    $0.id.value == ruuviTagSensor.id
                                }) {
                                    self?.notifySensorSettingsUpdate(
                                        sensorSettings: deleteSensorSettings,
                                        viewModel: viewModel
                                    )
                                }
                            }
                        default: break
                        }
                    })
                )
            }
        }
    }

    private func notifySensorSettingsUpdate(
        sensorSettings: SensorSettings?, viewModel: CardsViewModel
    ) {
        let currentRecord = viewModel.latestMeasurement.value
        let updatedRecord = currentRecord?.with(sensorSettings: sensorSettings)
        guard let updatedRecord = updatedRecord else {
            return
        }
        viewModel.update(updatedRecord)
        notifyViewModelUpdate(for: viewModel)
    }

    private func restartObservingRuuviTagLastRecords() {
        ruuviTagObserveLastRecordTokens.forEach({ $0.invalidate() })
        ruuviTagObserveLastRecordTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] (changes) in
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
                        self?.notifyViewModelUpdate(for: viewModel)

                        self?.processAlert(record: sensorRecord, viewModel: viewModel)
                    }
                }
                ruuviTagObserveLastRecordTokens.append(token)
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
                            self?.notifyViewModelUpdate(for: viewModel)
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
                    sSelf.restartObservingVirtualSensorsData()
                }
            case .insert(let sensor):
                sSelf.virtualSensors.append(sensor)
                sSelf.syncViewModel(ruuviTagSensor: nil,
                                    virtualSensor: sensor)
                if let viewModel = sSelf.viewModels.first(where: {
                    $0.id.value == sensor.id
                }) {
                    sSelf.router.openVirtualSensorSettings(
                        sensor: sensor,
                        temperature: viewModel.temperature.value
                    )
                }
                sSelf.restartObservingVirtualSensorsData()
            case .error(let error):
                sSelf.errorPresenter.present(error: error)
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] (change) in
            guard let sSelf = self else { return }
            switch change {
            case .initial(let ruuviTags):
                let ruuviTags = ruuviTags.reordered()
                sSelf.didLoadInitialRuuviTags = true
                sSelf.ruuviTags = ruuviTags
                // TODO: - Remove this migration code after version v1.3.2
                sSelf.migrateFirmwareVersion(for: ruuviTags)
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                sSelf.restartObservingRuuviTagLastRecords()
            case .insert(let sensor):
                sSelf.notifyRestartAdvertisementDaemon()
                sSelf.notifyRestartHeartBeatDaemon()
                sSelf.checkFirmwareVersion(for: sensor)
                sSelf.ruuviTags.append(sensor.any)

                // Avoid triggering the method when big changes is happening
                // such as login.
                if !sSelf.settings.isSyncing {
                    sSelf.syncViewModel(ruuviTagSensor: sensor,
                                        virtualSensor: nil)
                }

                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                if !sSelf.settings.isSyncing,
                    let viewModel = sSelf.viewModels.first(where: {
                    return ($0.luid.value != nil && $0.luid.value == sensor.luid?.any)
                        || ($0.mac.value != nil && $0.mac.value == sensor.macId?.any)
                }) {
                    let op = sSelf.ruuviStorage.readLatest(sensor.any)
                    op.on { [weak self] record in
                        if let record = record {
                            viewModel.update(record)
                            sSelf.openTagSettingsForNewSensor(viewModel: viewModel)
                        } else {
                            self?.ruuviStorage.readLast(sensor).on(success: { record in
                                if let record = record {
                                    viewModel.update(record)
                                }
                                sSelf.openTagSettingsForNewSensor(viewModel: viewModel)
                            })
                        }
                    }
                    sSelf.restartObservingRuuviTagLastRecords()
                }
            case .delete(let sensor):
                sSelf.ruuviTags.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.startObservingWebTags()
                sSelf.restartObservingRuuviTagLastRecords()
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
                    let viewModel = sSelf.view?.viewModels
                        .first(where: { $0.luid.value != nil && $0.luid.value == luid?.any })
                        ?? sSelf.view?.viewModels
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
                                    self?.notifyViewModelUpdate(for: viewModel)
                                }, failure: { [weak self] error in
                                    self?.errorPresenter.present(error: error)
                                })
                        }
                        if let webTag = webTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: webTag)
                                .on(success: { image in
                                    viewModel.background.value = image
                                    self?.notifyViewModelUpdate(for: viewModel)
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
                        self?.view?.showWebTagAPILimitExceededError()
                    } else if case .map(let mapError) = error {
                        let nsError = mapError as NSError
                        if nsError.code == 2, nsError.domain == "kCLErrorDomain" {
                            self?.view?.showReverseGeocodingFailed()
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
                                self?.notifyViewModelUpdate(for: viewModel)
                                if let latestRecord = viewModel.latestMeasurement.value {
                                    self?.processAlert(record: latestRecord,
                                                       viewModel: viewModel)
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
                                self?.notifyViewModelUpdate(for: viewModel)
                                if let latestRecord = viewModel.latestMeasurement.value {
                                    self?.processAlert(record: latestRecord,
                                                       viewModel: viewModel)
                                }
                            }
                         })
    }

    // swiftlint:disable:next function_body_length
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
                        = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                       let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                        sSelf.viewModels.filter({
                            ($0.luid.value != nil && ($0.luid.value == physicalSensor.luid?.any))
                            || ($0.mac.value != nil && ($0.mac.value == physicalSensor.macId?.any))
                        }).forEach({ (viewModel) in
                            if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                                viewModel.rhAlertLowerBound.value = sSelf.alertService
                                    .lowerRelativeHumidity(for: physicalSensor)
                                viewModel.rhAlertUpperBound.value = sSelf.alertService
                                    .upperRelativeHumidity(for: physicalSensor)
                                
                            } else {
                                viewModel.rhAlertLowerBound.value = 0
                                viewModel.rhAlertUpperBound.value = 100
                            }
                            sSelf.syncAlerts(ruuviTag: physicalSensor,
                                             viewModel: viewModel)
                            sSelf.updateIsOnState(of: type,
                                                  for: physicalSensor.id,
                                                  viewModel: viewModel)
                            sSelf.updateMutedTill(of: type,
                                                  for: physicalSensor.id,
                                                  viewModel: viewModel)
                        })
                    }
                    if let virtualSensor
                        = userInfo[RuuviServiceAlertDidChangeKey.virtualSensor] as? VirtualSensor,
                       let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                        sSelf.viewModels.filter({
                            ($0.id.value != nil && ($0.id.value == virtualSensor.id))
                        }).forEach({ (viewModel) in
                            if sSelf.alertService.hasRegistrations(for: virtualSensor) {
                                viewModel.alertState.value = .registered
                                sSelf.notifyViewModelUpdate(for: viewModel)
                            } else {
                                viewModel.alertState.value = .empty
                                sSelf.notifyViewModelUpdate(for: viewModel)
                            }
                            sSelf.updateIsOnState(of: type,
                                                  for: virtualSensor.id,
                                                  viewModel: viewModel)
                            sSelf.updateMutedTill(of: type,
                                                  for: virtualSensor.id,
                                                  viewModel: viewModel)
                        })
                    }
                }
            })
    }

    private func startListeningToRuuviTagsAlertStatus() {
        ruuviTags.forEach({ (ruuviTag) in
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
        })
    }

    private func startListeningToWebTagsAlertStatus() {
        virtualSensors.forEach({ alertHandler.subscribe(self, to: $0.id) })
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            self.router.openTagSettings(
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement.value,
                sensorSettings: sensorSettingsList
                    .first(where: {
                        ($0.luid != nil && $0.luid?.any == viewModel.luid.value)
                        || ($0.macId != nil && $0.macId?.any == viewModel.mac.value)
                    }),
                output: self)
        }
    }

    private func openTagSettingsForNewSensor(viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id.value }) {
            self.router.openTagSettings(
                with: viewModels,
                ruuviTagSensors: ruuviTags,
                virtualSensors: virtualSensors,
                sensorSettings: sensorSettingsList,
                scrollTo: viewModel,
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement.value,
                sensorSetting: sensorSettingsList
                    .first(where: {
                        ($0.luid != nil && $0.luid?.any == viewModel.luid.value)
                        || ($0.macId != nil && $0.macId?.any == viewModel.mac.value)
                    }),
                output: self
            )
        }
    }

    private func openCardView(viewModel: CardsViewModel, showCharts: Bool) {
        router.openCardImageView(with: viewModels,
                                 ruuviTagSensors: ruuviTags,
                                 virtualSensors: virtualSensors,
                                 sensorSettings: sensorSettingsList,
                                 scrollTo: viewModel,
                                 showCharts: showCharts,
                                 output: self)
    }

    private func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter
            .default
            .addObserver(forName: .DidOpenWithUniversalLink,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (_) in
                guard let email = self?.ruuviUser.email else { return }
                self?.view?.showAlreadyLoggedInAlert(with: email)
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
                self?.handleCloudModeState()
            })
    }

    /// The method handles all the operations when cloud mode toggle is turned on/off
    private func handleCloudModeState() {
        // Disconnect the owned cloud tags
        removeConnectionsForCloudTags()
        // Sync with cloud if cloud mode is turned on
        if ruuviUser.isAuthorized && settings.cloudModeEnabled {
            cloudSyncDaemon.refreshLatestRecord()
        }
        // Restart observing
        restartObserveRuuviTagAdvertisements()
        observeRuuviTagHeartbeats()
        syncViewModels()
    }

    private func removeConnectionsForCloudTags() {
        connectionPersistence.keepConnectionUUIDs.filter { (luid) -> Bool in
            ruuviTags.filter({ $0.isCloud }).contains(where: {
                $0.luid?.any != nil && $0.luid?.any == luid
            })
        }.forEach { (luid) in
            connectionPersistence.setKeepConnection(false, for: luid)
        }
    }

    // swiftlint:disable:next function_body_length
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureUnitDidChange,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
        }
        temperatureAccuracyToken = NotificationCenter
            .default
            .addObserver(forName: .TemperatureAccuracyDidChange,
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
        humidityAccuracyToken = NotificationCenter
            .default
            .addObserver(forName: .HumidityAccuracyDidChange,
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
        pressureAccuracyToken = NotificationCenter
            .default
            .addObserver(forName: .PressureUnitAccuracyChange,
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
        systemLanguageChangeToken = NotificationCenter
            .default
            .addObserver(forName: NSLocale.currentLocaleDidChangeNotification,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.systemLocaleDidChange()
        })
        dashboardTypeToken = NotificationCenter
            .default
            .addObserver(forName: .DashboardTypeDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                if let userInfo = notification.userInfo,
                   let type = userInfo[DashboardTypeKey.type] as? DashboardType {
                   self?.view?.dashboardType = type
                }
        })

        dashboardTapActionTypeToken = NotificationCenter
            .default
            .addObserver(forName: .DashboardTapActionTypeDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] (notification) in
                if let userInfo = notification.userInfo,
                   let type = userInfo[DashboardTapActionTypeKey.type] as?
                    DashboardTapActionType {
                    self?.view?.dashboardTapActionType = type
                }
            })
    }

    private func startObservingCloudSyncTokenState() {
        cloudSyncToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidFailForAuthorization,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.forceLogoutUser()
        })
    }
    
    @objc private func systemLocaleDidChange() {
        syncAppSettingsToAppGroupContainer()
    }

    fileprivate func askAppStoreReview(with sensorsCount: Int) {
        guard let dayDifference = Calendar.current.dateComponents(
            [.day],
            from: FileManager().appInstalledDate,
            to: Date()
        ).day, dayDifference > 7,
              sensorsCount > 0 else {
            return
        }
        AppStoreReviewHelper.askForReview(settings: settings)
    }

    private func startObserveCalibrationSettingsChange() {
        calibrationSettingsToken = NotificationCenter
            .default
            .addObserver(forName: .SensorCalibrationDidChange,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.restartObservingRuuviTagLastRecords()
            })
    }

    private func checkFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.interactor.checkAndUpdateFirmwareVersion(for: ruuviTag)
        }
    }

    private func migrateFirmwareVersion(for ruuviTags: [RuuviTagSensor]) {
        interactor.migrateFWVersionFromDefaults(for: ruuviTags)
    }

    private func syncAlerts(ruuviTag: PhysicalSensor, viewModel: CardsViewModel) {
        AlertType.allCases.forEach { (type) in
            switch type {
            case .temperature:
                sync(temperature: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .relativeHumidity:
                sync(relativeHumidity: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pressure:
                sync(pressure: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .signal:
                sync(signal: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .connection:
                sync(connection: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .movement:
                sync(movement: type, ruuviTag: ruuviTag, viewModel: viewModel)
            default:
                break
            }

            let alertStates = [
                viewModel.temperatureAlertState.value,
                viewModel.relativeHumidityAlertState.value,
                viewModel.pressureAlertState.value,
                viewModel.signalAlertState.value,
                viewModel.connectionAlertState.value,
                viewModel.movementAlertState.value
            ]

            if alertService.hasRegistrations(for: ruuviTag) {
                if alertStates.first(where: { alert in
                    alert == .firing
                }) != nil {
                    viewModel.alertState.value = .firing
                } else {
                    viewModel.alertState.value = .registered
                }
            } else {
                viewModel.alertState.value = .empty
            }

            notifyViewModelUpdate(for: viewModel)
        }
    }

    private func sync(temperature: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .temperature = alertService
            .alert(for: ruuviTag, of: temperature) {
            viewModel.isTemperatureAlertOn.value = true
        } else {
            viewModel.isTemperatureAlertOn.value = false
        }
        viewModel.temperatureAlertMutedTill.value = alertService
            .mutedTill(type: temperature,
                       for: ruuviTag)
    }

    private func sync(relativeHumidity: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .relativeHumidity = alertService.alert(for: ruuviTag,
                                                       of: relativeHumidity) {
            viewModel.isRelativeHumidityAlertOn.value = true
        } else {
            viewModel.isRelativeHumidityAlertOn.value = false
        }
        viewModel.relativeHumidityAlertMutedTill.value = alertService
            .mutedTill(type: relativeHumidity,
                       for: ruuviTag)
    }

    private func sync(pressure: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .pressure = alertService.alert(for: ruuviTag, of: pressure) {
            viewModel.isPressureAlertOn.value = true
        } else {
            viewModel.isPressureAlertOn.value = false
        }
        viewModel.pressureAlertMutedTill.value = alertService
            .mutedTill(type: pressure,
                       for: ruuviTag)
    }

    private func sync(signal: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .signal = alertService.alert(for: ruuviTag, of: signal) {
            viewModel.isSignalAlertOn.value = true
        } else {
            viewModel.isSignalAlertOn.value = false
        }
        viewModel.signalAlertMutedTill.value =
            alertService.mutedTill(type: signal,
                                   for: ruuviTag)
    }

    private func sync(connection: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .connection = alertService.alert(for: ruuviTag, of: connection) {
            viewModel.isConnectionAlertOn.value = true
        } else {
            viewModel.isConnectionAlertOn.value = false
        }
        viewModel.connectionAlertMutedTill.value = alertService
            .mutedTill(type: connection,
                       for: ruuviTag)
    }

    private func sync(movement: AlertType,
                      ruuviTag: PhysicalSensor,
                      viewModel: CardsViewModel) {
        if case .movement = alertService.alert(for: ruuviTag, of: movement) {
            viewModel.isMovementAlertOn.value = true
        } else {
            viewModel.isMovementAlertOn.value = false
        }
        viewModel.movementAlertMutedTill.value = alertService
            .mutedTill(type: movement,
                       for: ruuviTag)
    }

    private func reloadMutedTill() {
        for viewModel in viewModels {
            if let mutedTill = viewModel.temperatureAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.temperatureAlertMutedTill.value = nil
            }

            if let mutedTill = viewModel.relativeHumidityAlertMutedTill.value,
               mutedTill < Date() {
                viewModel.relativeHumidityAlertMutedTill.value = nil
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

            notifyViewModelUpdate(for: viewModel)
        }
    }

    private func updateMutedTill(of type: AlertType,
                                 for uuid: String,
                                 viewModel: CardsViewModel) {
        var observable: Observable<Date?>
        switch type {
        case .temperature:
            observable = viewModel.temperatureAlertMutedTill
        case .relativeHumidity:
            observable = viewModel.relativeHumidityAlertMutedTill
        case .pressure:
            observable = viewModel.pressureAlertMutedTill
        case .signal:
            observable = viewModel.signalAlertMutedTill
        case .connection:
            observable = viewModel.connectionAlertMutedTill
        case .movement:
            observable = viewModel.movementAlertMutedTill
        default:
            // Should never be here
            observable = viewModel.temperatureAlertMutedTill
        }

        let date = alertService.mutedTill(type: type, for: uuid)
        if date != observable.value {
            observable.value = date
        }
        notifyViewModelUpdate(for: viewModel)
    }

    private func updateIsOnState(of type: AlertType,
                                 for uuid: String,
                                 viewModel: CardsViewModel) {
        var observable: Observable<Bool?>
        switch type {
        case .temperature:
            observable = viewModel.isTemperatureAlertOn
        case .relativeHumidity:
            observable = viewModel.isRelativeHumidityAlertOn
        case .pressure:
            observable = viewModel.isPressureAlertOn
        case .signal:
            observable = viewModel.isSignalAlertOn
        case .connection:
            observable = viewModel.isConnectionAlertOn
        case .movement:
            observable = viewModel.isMovementAlertOn
        default:
            // Should never be here
            observable = viewModel.isTemperatureAlertOn
        }

        let isOn = alertService.isOn(type: type, for: uuid)
        if isOn != observable.value {
            observable.value = isOn
        }
        notifyViewModelUpdate(for: viewModel)
    }

    /// Log out user if the auth token is expired.
    private func forceLogoutUser() {
        guard ruuviUser.isAuthorized else { return }
        activityPresenter.increment()
        cloudNotificationService.unregister(
            token: pnManager.fcmToken,
            tokenId: nil
        ).on(success: { [weak self] _ in
            self?.pnManager.fcmToken = nil
            self?.pnManager.fcmTokenLastRefreshed = nil
        })

        authService.logout()
            .on(success: { [weak self] _ in
                // Stop observing cloud mode state.
                // To break the simlatanous access of it while making it false
                // and observing it at the same time.
                self?.cloudModeToken?.invalidate()
                self?.cloudModeToken = nil
                self?.settings.cloudModeEnabled = false
                self?.syncViewModels()
                self?.reloadWidgets()
                self?.handleCloudModeState()
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }

    private func notifyViewModelUpdate(for viewModel: CardsViewModel) {
        view?.applyUpdate(to: viewModel)
    }

    private func notifyRestartAdvertisementDaemon() {
            // Notify daemon to restart
        NotificationCenter
            .default
            .post(name: .RuuviTagAdvertisementDaemonShouldRestart,
                  object: nil,
                  userInfo: nil)
    }

    private func notifyRestartHeartBeatDaemon() {
            // Notify daemon to restart
        NotificationCenter
            .default
            .post(name: .RuuviTagHeartBeatDaemonShouldRestart,
                  object: nil,
                  userInfo: nil)
    }
}
// swiftlint:enable file_length trailing_whitespace
