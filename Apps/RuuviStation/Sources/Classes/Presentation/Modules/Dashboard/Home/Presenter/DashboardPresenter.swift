import BTKit
import CoreBluetooth
import Foundation
import Future
import Humidity
import RuuviContext
import RuuviCore
import RuuviDaemon
import RuuviLocal
import RuuviNotification
import RuuviNotifier
import RuuviOntology
import RuuviPresenters
import RuuviReactor
import RuuviService
import RuuviStorage
import RuuviUser
import UIKit
import WidgetKit

// swiftlint:disable file_length
class DashboardPresenter: DashboardModuleInput {
    weak var view: DashboardViewInput?
    var router: DashboardRouterInput!
    var interactor: DashboardInteractorInput!
    var errorPresenter: ErrorPresenter!
    var settings: RuuviLocalSettings!
    var foreground: BTForeground!
    var background: BTBackground!
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
    var cloudSyncService: RuuviServiceCloudSync!
    private var ruuviTagToken: RuuviReactorToken?
    private var ruuviTagObserveLastRecordTokens = [RuuviReactorToken]()
    private var advertisementTokens = [ObservationToken]()
    private var heartbeatTokens = [ObservationToken]()
    private var sensorSettingsTokens = [RuuviReactorToken]()
    private var backgroundToken: NSObjectProtocol?
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
    private var widgetRefreshIntervalToken: NSObjectProtocol?
    private var systemLanguageChangeToken: NSObjectProtocol?
    private var calibrationSettingsToken: NSObjectProtocol?
    private var dashboardTypeToken: NSObjectProtocol?
    private var dashboardTapActionTypeToken: NSObjectProtocol?
    private var cloudSyncSuccessStateToken: NSObjectProtocol?
    private var cloudSyncFailStateToken: NSObjectProtocol?
    private var sensorOrderChangeToken: NSObjectProtocol?
    private var ruuviTags = [AnyRuuviTagSensor]()
    private var sensorSettingsList = [SensorSettings]()
    private var viewModels: [CardsViewModel] = [] {
        didSet {
            view?.viewModels = viewModels
        }
    }

    private var didLoadInitialRuuviTags = false
    private let appGroupDefaults = UserDefaults(
        suiteName: AppGroupConstants.appGroupSuiteIdentifier
    )
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    deinit {
        ruuviTagToken?.invalidate()
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        advertisementTokens.forEach { $0.invalidate() }
        heartbeatTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.forEach { $0.invalidate() }
        stateToken?.invalidate()
        backgroundToken?.invalidate()
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
        widgetRefreshIntervalToken?.invalidate()
        systemLanguageChangeToken?.invalidate()
        calibrationSettingsToken?.invalidate()
        dashboardTypeToken?.invalidate()
        dashboardTapActionTypeToken?.invalidate()
        cloudSyncSuccessStateToken?.invalidate()
        cloudSyncFailStateToken?.invalidate()
        sensorOrderChangeToken?.invalidate()
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
        startObservingBackgroundChanges()
        startObservingDaemonsErrors()
        startObservingConnectionPersistenceNotifications()
        startObservingDidConnectDisconnectNotifications()
        startObservingAlertChanges()
        startObservingCloudModeNotification()
        startListeningToSettings()
        startObserveCalibrationSettingsChange()
        startObservingCloudSyncSuccessTokenState()
        startObservingCloudSyncFailTokenState()
        startObservingSensorOrderChanges()
        triggerFullHistorySync()
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

    func viewDidTriggerSignIn() {
        router.openSignIn(output: self)
    }

    func viewDidTriggerAddSensors() {
        router.openDiscover(delegate: self)
    }

    func viewDidTriggerBuySensors() {
        router.openRuuviProductsPage()
    }

    func viewDidTriggerSettings(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || background.isConnected(uuid: luid.value)
                    || !viewModel.isConnectable
                    || !viewModel.isOwner
                    || (settings.cloudModeEnabled && viewModel.isCloud) {
                    openTagSettingsScreens(viewModel: viewModel)
                } else {
                    view?.showKeepConnectionDialogSettings(for: viewModel)
                }
            } else {
                openTagSettingsScreens(viewModel: viewModel)
            }
        }
    }

    func viewDidTriggerChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            if settings.keepConnectionDialogWasShown(for: luid)
                || background.isConnected(uuid: luid.value)
                || !viewModel.isConnectable
                || !viewModel.isOwner
                || (settings.cloudModeEnabled && viewModel.isCloud) {
                openCardView(viewModel: viewModel, showCharts: true)
            } else {
                view?.showKeepConnectionDialogChart(for: viewModel)
            }
        } else if viewModel.mac != nil {
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidTriggerOpenCardImageView(for viewModel: CardsViewModel?) {
        guard let viewModel else { return }
        openCardView(viewModel: viewModel, showCharts: false)
    }

    func viewDidTriggerOpenSensorCardFromWidget(for viewModel: CardsViewModel?) {
        guard let viewModel else { return }
        openCardView(
            viewModel: viewModel,
            showCharts: settings.dashboardTapActionType == .chart
        )
    }

    func viewDidTriggerDashboardCard(for viewModel: CardsViewModel) {
        switch settings.dashboardTapActionType {
        case .card:
            viewDidTriggerOpenCardImageView(for: viewModel)
        case .chart:
            viewDidTriggerChart(for: viewModel)
        }
    }

    func viewDidTriggerChangeBackground(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                router.openBackgroundSelectionView(ruuviTag: ruuviTagSensor)
            }
        }
    }

    func viewDidTriggerRename(for viewModel: CardsViewModel) {
        view?.showSensorNameRenameDialog(
            for: viewModel,
            sortingType: dashboardSortingType()
        )
    }

    func viewDidTriggerShare(for viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
            router.openShare(for: ruuviTag)
        }
    }

    func viewDidTriggerRemove(for viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
            router.openRemove(for: ruuviTag, output: self)
        }
    }

    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
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

    func viewDidTriggerPullToRefresh() {
        cloudSyncDaemon.refreshImmediately()
    }

    func viewDidRenameTag(to name: String, viewModel: CardsViewModel) {
        guard let ruuviTag = ruuviTags.first(where: {
            $0.id == viewModel.id
        })
        else {
            return
        }

        ruuviSensorPropertiesService.set(name: name, for: ruuviTag)
            .on(failure: { [weak self] error in
                self?.errorPresenter.present(error: error)
            })
    }

    func viewDidReorderSensors(
        with type: DashboardSortingType,
        orderedIds: [String]
    ) {
        settings.dashboardSensorOrder = orderedIds
        ruuviAppSettingsService.set(dashboardSensorOrder: orderedIds)
        viewModels = reorder(viewModels)
        view?.dashboardSortingType = dashboardSortingType()
    }

    func viewDidResetManualSorting() {
        view?.showSensorSortingResetConfirmationDialog()
    }

    func viewDidHideSignInBanner() {
        if let currentAppVersion = currentAppVersion() {
            settings.setDashboardSignInBannerHidden(for: currentAppVersion)
            view?.shouldShowSignInBanner = false
        }
    }
}

// MARK: - MenuModuleOutput

extension DashboardPresenter: MenuModuleOutput {
    func menu(module: MenuModuleInput, didSelectAddRuuviTag _: Any?) {
        module.dismiss()
        router.openDiscover(delegate: self)
    }

    func menu(module: MenuModuleInput, didSelectSettings _: Any?) {
        module.dismiss()
        router.openSettings()
    }

    func menu(module: MenuModuleInput, didSelectAbout _: Any?) {
        module.dismiss()
        router.openAbout()
    }

    func menu(module: MenuModuleInput, didSelectWhatToMeasure _: Any?) {
        module.dismiss()
        router.openWhatToMeasurePage()
    }

    func menu(module: MenuModuleInput, didSelectGetMoreSensors _: Any?) {
        module.dismiss()
        router.openRuuviProductsPageFromMenu()
    }

    func menu(module: MenuModuleInput, didSelectFeedback _: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let sSelf = self else { return }
            sSelf.mailComposerPresenter.present(
                email: sSelf.feedbackEmail,
                subject: sSelf.feedbackSubject,
                body: "\n\n" + summary
            )
        }
    }

    func menu(module: MenuModuleInput, didSelectSignIn _: Any?) {
        module.dismiss()
        router.openSignIn(output: self)
    }

    func menu(module: MenuModuleInput, didSelectOpenConfig _: Any?) {
        module.dismiss()
    }

    func menu(module: MenuModuleInput, didSelectOpenMyRuuviAccount _: Any?) {
        module.dismiss()
        router.openMyRuuviAccount()
    }
}

// MARK: - SignInBenefitsModuleOutput

extension DashboardPresenter: SignInBenefitsModuleOutput {
    func signIn(
        module: SignInBenefitsModuleInput,
        didSuccessfulyLogin _: Any?
    ) {
        triggerFullHistorySync()
        startObservingRuuviTags()
        startObservingCloudModeNotification()
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }

    func signIn(
        module: SignInBenefitsModuleInput,
        didCloseSignInWithoutAttempt _: Any?
    ) {
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }

    func signIn(
        module: SignInBenefitsModuleInput,
        didSelectUseWithoutAccount _: Any?
    ) {
        module.dismiss(completion: {
            AppUtility.lockOrientation(.all)
        })
    }
}

extension DashboardPresenter: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true)
    }

    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _ router: DiscoverRouter,
        ruuviTag: RuuviTagSensor
    ) {
        router.viewController.dismiss(animated: true)
        if let viewModel = viewModels.first(where: {
            $0.id == ruuviTag.id
        }) {
            self.router.openCardImageView(
                with: viewModels,
                ruuviTagSensors: ruuviTags,
                sensorSettings: sensorSettingsList,
                scrollTo: viewModel,
                showCharts: false,
                output: self
            )
        }
    }
}

// MARK: - DashboardRouterDelegate

extension DashboardPresenter: DashboardRouterDelegate {
    func shouldDismissDiscover() -> Bool {
        viewModels.count > 0
    }
}

// MARK: - RuuviNotifierObserver

extension DashboardPresenter: RuuviNotifierObserver {
    func ruuvi(notifier _: RuuviNotifier, isTriggered _: Bool, for _: String) {
        // No op here.
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func ruuvi(
        notifier _: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        viewModels
            .filter { $0.luid?.value == uuid || $0.mac?.value == uuid }
            .forEach { viewModel in
                let isFireable = viewModel.isCloud ||
                    viewModel.isConnected ||
                    viewModel.serviceUUID != nil
                switch alertType {
                case .temperature:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.temperatureAlertState = newValue
                case .relativeHumidity:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.relativeHumidityAlertState = newValue
                case .pressure:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pressureAlertState = newValue
                case .signal:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.signalAlertState = newValue
                case .carbonDioxide:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.carbonDioxideAlertState = newValue
                case .pMatter1:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pMatter1AlertState = newValue
                case .pMatter2_5:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pMatter2_5AlertState = newValue
                case .pMatter4:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pMatter4AlertState = newValue
                case .pMatter10:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.pMatter10AlertState = newValue
                case .voc:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.vocAlertState = newValue
                case .nox:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.noxAlertState = newValue
                case .sound:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.soundAlertState = newValue
                case .luminosity:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.luminosityAlertState = newValue
                case .connection:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.connectionAlertState = newValue
                case .movement:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.movementAlertState = newValue
                case .cloudConnection:
                    let isTriggered = isTriggered && isFireable
                    let newValue: AlertState? = isTriggered ? .firing : .registered
                    viewModel.cloudConnectionAlertState = newValue
                default:
                    break
                }
                let alertStates = [
                    viewModel.temperatureAlertState,
                    viewModel.relativeHumidityAlertState,
                    viewModel.pressureAlertState,
                    viewModel.signalAlertState,
                    viewModel.carbonDioxideAlertState,
                    viewModel.pMatter1AlertState,
                    viewModel.pMatter2_5AlertState,
                    viewModel.pMatter4AlertState,
                    viewModel.pMatter10AlertState,
                    viewModel.vocAlertState,
                    viewModel.noxAlertState,
                    viewModel.soundAlertState,
                    viewModel.luminosityAlertState,
                    viewModel.connectionAlertState,
                    viewModel.movementAlertState,
                    viewModel.cloudConnectionAlertState,
                ]
                if alertStates.first(where: { alert in
                    alert == .firing
                }) != nil {
                    viewModel.alertState = .firing
                } else {
                    viewModel.alertState = .registered
                }
            }
    }
}

// MARK: - CardsModuleOutput

extension DashboardPresenter: CardsModuleOutput {
    func cardsViewDidDismiss(module: CardsModuleInput) {
        module.dismiss(completion: nil)
    }

    func cardsViewDidRefresh(module _: CardsModuleInput) {
        // No op.
    }
}

// MARK: - TagSettingsModuleOutput

extension DashboardPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag _: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            self?.startObservingRuuviTags()
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - SensorRemovalModuleOutput

extension DashboardPresenter: SensorRemovalModuleOutput {
    func sensorRemovalDidRemoveTag(
        module: SensorRemovalModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            self?.startObservingRuuviTags()
        })
    }

    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Private

extension DashboardPresenter {

    // swiftlint:disable:next function_body_length
    private func syncViewModels() {
        view?.userSignedInOnce = settings.signedInAtleastOnce
        view?.isAuthorized = ruuviUser.isAuthorized
        view?.dashboardType = settings.dashboardType
        view?.dashboardTapActionType = settings.dashboardTapActionType
        view?.dashboardSortingType = dashboardSortingType()

        let ruuviViewModels = ruuviTags.compactMap { ruuviTag -> CardsViewModel in
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: { image in
                    viewModel.background = image
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            if let luid = ruuviTag.luid {
                viewModel.isConnected = background.isConnected(uuid: luid.value)
            } else if let macId = ruuviTag.macId {
                viewModel.networkSyncStatus = localSyncState.getSyncStatus(for: macId)
                viewModel.isConnected = false
            } else {
                assertionFailure()
            }
            viewModel.rhAlertLowerBound = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound = alertService
                .upperRelativeHumidity(for: ruuviTag)

            // Inject previous record if available that will prevent showing nil
            // value while this method is rebuilding the collection and fetching
            // latest record from storage asynchronously.
            if let previousRecord = viewModels.first(where: {
                $0.id == ruuviTag.id
            })?.latestMeasurement {
                viewModel.update(previousRecord)
            }

            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record {
                    viewModel.update(record)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            return viewModel
        }

        let vms = reorder(ruuviViewModels)
        if didLoadInitialRuuviTags {
            view?.showNoSensorsAddedMessage(show: vms.isEmpty)
            askAppStoreReview(with: vms.count)
        }

        viewModels = vms

        // Show sign in banner if user signed in at least once,
        // but currently not authorized, there is at least one BT sensor and
        // user did not already hide the banner for current app version by tapping
        // close button.
        if let currentAppVersion = currentAppVersion() {
            view?.shouldShowSignInBanner =
                    settings.signedInAtleastOnce && !ruuviUser.isAuthorized &&
                    viewModels.count > 0 &&
                    !settings.dashboardSignInBannerHidden(for: currentAppVersion)
        } else {
            view?.shouldShowSignInBanner = false
        }
    }

    private func syncViewModel(ruuviTagSensor: RuuviTagSensor?) {
        if let ruuviTag = ruuviTagSensor {
            let viewModel = CardsViewModel(ruuviTag)
            ruuviSensorPropertiesService.getImage(for: ruuviTag)
                .on(success: { image in
                    viewModel.background = image
                }, failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
            if let luid = ruuviTag.luid {
                viewModel.isConnected = background.isConnected(uuid: luid.value)
            } else if let macId = ruuviTag.macId {
                viewModel.networkSyncStatus = localSyncState.getSyncStatus(for: macId)
                viewModel.isConnected = false
            } else {
                assertionFailure()
            }
            viewModel.rhAlertLowerBound = alertService
                .lowerRelativeHumidity(for: ruuviTag)
            viewModel.rhAlertUpperBound = alertService
                .upperRelativeHumidity(for: ruuviTag)

            // Inject previous record if available that will prevent showing nil
            // value while this method is rebuilding the collection and fetching
            // latest record from storage asynchronously.
            if let previousRecord = viewModels.first(where: {
                $0.id == ruuviTag.id
            })?.latestMeasurement {
                viewModel.update(previousRecord)
            }

            syncAlerts(ruuviTag: ruuviTag, viewModel: viewModel)
            let op = ruuviStorage.readLatest(ruuviTag)
            op.on { [weak self] record in
                if let record {
                    viewModel.update(record)
                    self?.processAlert(record: record, viewModel: viewModel)
                }
            }

            if dashboardSortingType() == .alphabetical {
                viewModels.append(viewModel)
                viewModels = reorder(viewModels)
            } else {
                // For manual sorting, newly added sensor will be sent to the top
                viewModels.insert(viewModel, at: 0)
                let macIds = viewModels.compactMap { $0.mac?.value }
                viewDidReorderSensors(with: .manual, orderedIds: macIds)
            }
        }
    }

    private func processAlert(
        record: RuuviTagSensorRecord,
        viewModel: CardsViewModel
    ) {
        if viewModel.isCloud,
           let macId = viewModel.mac {
            alertHandler.processNetwork(
                record: record,
                trigger: false,
                for: macId
            )
        } else {
            if viewModel.luid != nil {
                alertHandler.process(record: record, trigger: false)
            } else {
                guard let macId = viewModel.mac
                else {
                    return
                }
                alertHandler.processNetwork(record: record, trigger: false, for: macId)
            }
        }
    }

    private func reorder(_ viewModels: [CardsViewModel]) -> [CardsViewModel] {
        let sortedSensors: [String] = settings.dashboardSensorOrder
        let sortedAndUniqueArray = viewModels.reduce(
            into: [CardsViewModel]()
        ) { result, element in
            if !result.contains(element) {
                result.append(element)
            }
        }

        if !sortedSensors.isEmpty {
            return sortedAndUniqueArray.sorted { (first, second) -> Bool in
                guard let firstMacId = first.mac?.value,
                      let secondMacId = second.mac?.value else { return false }
                let firstIndex = sortedSensors.firstIndex(of: firstMacId) ?? Int.max
                let secondIndex = sortedSensors.firstIndex(of: secondMacId) ?? Int.max
                return firstIndex < secondIndex
            }
        } else {
            return sortedAndUniqueArray.sorted { (first, second) -> Bool in
                let firstName = first.name.lowercased()
                let secondName = second.name.lowercased()
                return firstName < secondName
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func syncAppSettingsToAppGroupContainer() {
        appGroupDefaults?.set(
            ruuviUser.isAuthorized,
            forKey: AppGroupConstants.isAuthorizedUDKey
        )

        // Temperature
        var temperatureUnitInt = 2
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
        var humidityUnitInt = 0
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
            forKey: AppGroupConstants.humidityAccuracyKey
        )

        // Pressure
        appGroupDefaults?.set(
            settings.pressureUnit.hashValue,
            forKey: AppGroupConstants.pressureUnitKey
        )

        appGroupDefaults?.set(
            settings.pressureAccuracy.value,
            forKey: AppGroupConstants.pressureAccuracyKey
        )

        // Widget refresh interval
        appGroupDefaults?.set(
            settings.widgetRefreshIntervalMinutes,
            forKey: AppGroupConstants.widgetRefreshIntervalKey
        )

        appGroupDefaults?.set(
            settings.forceRefreshWidget,
            forKey: AppGroupConstants.forceRefreshWidgetKey
        )

        // Reload widget
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }

    private func syncHasCloudSensorToAppGroupContainer(with sensors: [AnyRuuviTagSensor]) {
        let cloudSensors = sensors.filter { $0.isCloudSensor ?? false }
        appGroupDefaults?.set(
            cloudSensors.count > 0,
            forKey: AppGroupConstants.hasCloudSensorsKey
        )
        appGroupDefaults?.synchronize()
    }

    private func startObservingBluetoothState() {
        guard !ruuviTags.filter({ !$0.isCloud  }).isEmpty else { return }
        stateToken = foreground.state(self, closure: { observer, state in
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
        heartbeatTokens.forEach { $0.invalidate() }
        heartbeatTokens.removeAll()
        connectionPersistence.keepConnectionUUIDs.filter { luid -> Bool in
            ruuviTags.filter { !(settings.cloudModeEnabled && $0.isCloud) && $0.isOwner }
                .contains(where: { $0.luid?.any != nil && $0.luid?.any == luid })
        }.forEach { luid in
            heartbeatTokens.append(background.observe(self, uuid: luid.value) { [weak self] _, device in
                if let ruuviTag = device.ruuvi?.tag,
                   let viewModel = self?.viewModels.first(
                    where: { $0.luid?.value == ruuviTag.uuid.luid.value }
                   ) {
                    let sensorSettings = self?.sensorSettingsList
                        .first(where: {
                            ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                                || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                        })
                    let record = ruuviTag
                        .with(source: .heartbeat)
                        .with(sensorSettings: sensorSettings)
                    viewModel.update(
                        record
                    )
                    self?.alertHandler.process(record: record, trigger: false)
                }
            })
        }
    }

    private func restartObserveRuuviTagAdvertisements() {
        advertisementTokens.forEach { $0.invalidate() }
        advertisementTokens.removeAll()
        for viewModel in viewModels {
            let shouldAvoidObserving =
                ruuviUser.isAuthorized &&
                settings.cloudModeEnabled &&
                viewModel.isCloud
            if shouldAvoidObserving {
                continue
            }
            if viewModel.type == .ruuvi,
               let luid = viewModel.luid {
                advertisementTokens.append(foreground.observe(self, uuid: luid.value) { [weak self] _, device in
                    if let ruuviTag = device.ruuvi?.tag,
                       let viewModel = self?.viewModels.first(where: { $0.luid == ruuviTag.uuid.luid.any }) {
                        let sensorSettings = self?.sensorSettingsList
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
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

    private func updateSensorSettings(
        _ sensorSettings: SensorSettings,
        _ ruuviTagSensor: AnyRuuviTagSensor
    ) {
        if let updateIndex = sensorSettingsList.firstIndex(
            where: { $0.id == sensorSettings.id }
        ) {
            sensorSettingsList[updateIndex] = sensorSettings
            if let viewModel = viewModels.first(where: {
                $0.id == ruuviTagSensor.id
            }) {
                notifySensorSettingsUpdate(
                    sensorSettings: sensorSettings,
                    viewModel: viewModel
                )
            }
        } else {
            sensorSettingsList.append(sensorSettings)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func observeSensorSettings() {
        sensorSettingsTokens.forEach { $0.invalidate() }
        sensorSettingsTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                sensorSettingsTokens.append(
                    ruuviReactor.observe(ruuviTagSensor) { [weak self] change in
                        guard let sSelf = self else { return }
                        switch change {
                        case let .insert(sensorSettings):
                            self?.sensorSettingsList.append(sensorSettings)
                            if let viewModel = sSelf.viewModels.first(where: {
                                $0.id == ruuviTagSensor.id
                            }) {
                                self?.notifySensorSettingsUpdate(
                                    sensorSettings: sensorSettings,
                                    viewModel: viewModel
                                )
                            }
                        case let .update(updateSensorSettings):
                            self?.updateSensorSettings(updateSensorSettings, ruuviTagSensor)
                        case let .delete(deleteSensorSettings):
                            if let deleteIndex = self?.sensorSettingsList.firstIndex(
                                where: { $0.id == deleteSensorSettings.id }
                            ) {
                                self?.sensorSettingsList.remove(at: deleteIndex)
                                if let viewModel = sSelf.viewModels.first(where: {
                                    $0.id == ruuviTagSensor.id
                                }) {
                                    self?.notifySensorSettingsUpdate(
                                        sensorSettings: deleteSensorSettings,
                                        viewModel: viewModel
                                    )
                                }
                            }
                        case let .initial(initialSensorSettings):
                            initialSensorSettings.forEach {
                                self?.updateSensorSettings($0, ruuviTagSensor)
                            }
                        case let .error(error):
                            self?.errorPresenter.present(error: error)
                        }
                    }
                )
            }
        }
    }

    private func notifySensorSettingsUpdate(
        sensorSettings: SensorSettings?, viewModel: CardsViewModel
    ) {
        let currentRecord = viewModel.latestMeasurement
        let updatedRecord = currentRecord?.with(sensorSettings: sensorSettings)
        guard let updatedRecord
        else {
            return
        }
        viewModel.update(updatedRecord)
    }

    private func restartObservingRuuviTagLastRecords() {
        ruuviTagObserveLastRecordTokens.forEach { $0.invalidate() }
        ruuviTagObserveLastRecordTokens.removeAll()
        for viewModel in viewModels {
            if viewModel.type == .ruuvi,
               let ruuviTagSensor = ruuviTags.first(where: { $0.id == viewModel.id }) {
                let token = ruuviReactor.observeLatest(ruuviTagSensor) { [weak self] changes in
                    if case let .update(anyRecord) = changes,
                       let viewModel = self?.viewModels
                           .first(where: {
                               ($0.luid != nil && ($0.luid == anyRecord?.luid?.any))
                                   || ($0.mac != nil && ($0.mac == anyRecord?.macId?.any))
                           }),
                           let record = anyRecord {
                        let sensorSettings = self?.sensorSettingsList
                            .first(where: {
                                ($0.luid?.any != nil && $0.luid?.any == viewModel.luid)
                                    || ($0.macId?.any != nil && $0.macId?.any == viewModel.mac)
                            })
                        let sensorRecord = record.with(sensorSettings: sensorSettings)
                        viewModel.update(sensorRecord)
                        self?.processAlert(record: sensorRecord, viewModel: viewModel)
                    }
                }
                ruuviTagObserveLastRecordTokens.append(token)
            }
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func startObservingRuuviTags() {
        ruuviTagToken?.invalidate()
        ruuviTagToken = ruuviReactor.observe { [weak self] change in
            guard let sSelf = self else { return }
            switch change {
            case let .initial(ruuviTags):
                let ruuviTags = ruuviTags.reordered()
                sSelf.didLoadInitialRuuviTags = true
                sSelf.ruuviTags = ruuviTags
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.restartObservingRuuviTagLastRecords()
                sSelf.syncHasCloudSensorToAppGroupContainer(with: ruuviTags)
            case let .insert(sensor):
                sSelf.notifyRestartAdvertisementDaemon()
                sSelf.notifyRestartHeartBeatDaemon()
                sSelf.checkFirmwareVersion(for: sensor)
                sSelf.ruuviTags.append(sensor.any)
                sSelf.syncHasCloudSensorToAppGroupContainer(with: sSelf.ruuviTags)

                // Avoid triggering the method when big changes is happening
                // such as login.
                if !sSelf.settings.isSyncing {
                    sSelf.syncViewModel(ruuviTagSensor: sensor)
                }

                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                if !sSelf.settings.isSyncing,
                   let viewModel = sSelf.viewModels.first(where: {
                       ($0.luid != nil && $0.luid == sensor.luid?.any)
                           || ($0.mac != nil && $0.mac == sensor.macId?.any)
                   }) {
                    let op = sSelf.ruuviStorage.readLatest(sensor.any)
                    op.on { [weak self] record in
                        if let record {
                            viewModel.update(record)
                            sSelf.openTagSettingsForNewSensor(viewModel: viewModel)
                        } else {
                            self?.ruuviStorage.readLast(sensor).on(success: { record in
                                if let record {
                                    viewModel.update(record)
                                }
                                sSelf.openTagSettingsForNewSensor(viewModel: viewModel)
                            })
                        }
                    }
                    sSelf.restartObservingRuuviTagLastRecords()
                }
            case let .delete(sensor):
                sSelf.ruuviTags.removeAll(where: { $0.id == sensor.id })
                sSelf.syncViewModels()
                sSelf.startListeningToRuuviTagsAlertStatus()
                sSelf.observeRuuviTags()
                sSelf.restartObservingRuuviTagLastRecords()
                sSelf.syncHasCloudSensorToAppGroupContainer(with: sSelf.ruuviTags)
            case let .error(error):
                sSelf.errorPresenter.present(error: error)
            case let .update(sensor):
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
                sSelf.syncHasCloudSensorToAppGroupContainer(with: sSelf.ruuviTags)
            }
        }
    }

    private func startObservingBackgroundChanges() {
        backgroundToken?.invalidate()
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
                    let viewModel = sSelf.view?.viewModels
                        .first(where: { $0.luid != nil && $0.luid == luid?.any })
                        ?? sSelf.view?.viewModels
                        .first(where: { $0.mac != nil && $0.mac == macId?.any })
                    if let viewModel {
                        let ruuviTag = sSelf.ruuviTags
                            .first(where: { $0.luid != nil && $0.luid?.any == luid?.any })
                            ?? sSelf.ruuviTags
                            .first(where: { $0.macId != nil && $0.macId?.any == macId?.any })
                        if let ruuviTag {
                            sSelf.ruuviSensorPropertiesService.getImage(for: ruuviTag)
                                .on(success: { image in
                                    viewModel.background = image
                                }, failure: { [weak self] error in
                                    self?.errorPresenter.present(error: error)
                                })
                        }
                    }
                }
            }
    }

    // swiftlint:disable:next function_body_length
    func startObservingDaemonsErrors() {
        ruuviTagAdvertisementDaemonFailureToken?.invalidate()
        ruuviTagAdvertisementDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagAdvertisementDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagAdvertisementDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagPropertiesDaemonFailureToken?.invalidate()
        ruuviTagPropertiesDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagPropertiesDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagPropertiesDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagHeartbeatDaemonFailureToken?.invalidate()
        ruuviTagHeartbeatDaemonFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagHeartbeatDaemonDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagHeartbeatDaemonDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
        ruuviTagReadLogsOperationFailureToken?.invalidate()
        ruuviTagReadLogsOperationFailureToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviTagReadLogsOperationDidFail,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let error = userInfo[RuuviTagReadLogsOperationDidFailKey.error] as? RUError {
                        self?.errorPresenter.present(error: error)
                    }
                }
            )
    }

    func startObservingConnectionPersistenceNotifications() {
        startKeepingConnectionToken?.invalidate()
        startKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(
                forName: .ConnectionPersistenceDidStartToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.observeRuuviTagHeartbeats()
                }
            )
        stopKeepingConnectionToken?.invalidate()
        stopKeepingConnectionToken = NotificationCenter
            .default
            .addObserver(
                forName: .ConnectionPersistenceDidStopToKeepConnection,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.observeRuuviTagHeartbeats()
                }
            )
    }

    func startObservingDidConnectDisconnectNotifications() {
        didConnectToken?.invalidate()
        didConnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidConnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidConnectKey.uuid] as? String,
                       let viewModel = self?.viewModels.first(where: { $0.luid == uuid.luid.any }) {
                        viewModel.isConnected = true
                        if let latestRecord = viewModel.latestMeasurement {
                            self?.processAlert(
                                record: latestRecord,
                                viewModel: viewModel
                            )
                        }
                    }
                }
            )
        didDisconnectToken?.invalidate()
        didDisconnectToken = NotificationCenter
            .default
            .addObserver(
                forName: .BTBackgroundDidDisconnect,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let uuid = userInfo[BTBackgroundDidDisconnectKey.uuid] as? String,
                       let viewModel = self?.viewModels.first(where: { $0.luid == uuid.luid.any }) {
                        viewModel.isConnected = false
                        if let latestRecord = viewModel.latestMeasurement {
                            self?.processAlert(
                                record: latestRecord,
                                viewModel: viewModel
                            )
                        }
                    }
                }
            )
    }

    private func startObservingAlertChanges() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let sSelf = self else { return }
                    if let userInfo = notification.userInfo {
                        if let physicalSensor
                            = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
                            let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {
                            sSelf.viewModels.filter {
                                ($0.luid != nil && ($0.luid == physicalSensor.luid?.any))
                                    || ($0.mac != nil && ($0.mac == physicalSensor.macId?.any))
                            }.forEach { viewModel in
                                if sSelf.alertService.hasRegistrations(for: physicalSensor) {
                                    viewModel.rhAlertLowerBound = sSelf.alertService
                                        .lowerRelativeHumidity(for: physicalSensor)
                                    viewModel.rhAlertUpperBound = sSelf.alertService
                                        .upperRelativeHumidity(for: physicalSensor)
                                } else {
                                    viewModel.rhAlertLowerBound = 0
                                    viewModel.rhAlertUpperBound = 100
                                }
                                sSelf.syncAlerts(
                                    ruuviTag: physicalSensor,
                                    viewModel: viewModel
                                )
                                sSelf.updateIsOnState(
                                    of: type,
                                    for: physicalSensor.id,
                                    viewModel: viewModel
                                )
                                sSelf.updateMutedTill(
                                    of: type,
                                    for: physicalSensor.id,
                                    viewModel: viewModel
                                )
                                sSelf.triggerAlertsIfNeeded()
                            }
                        }
                    }
                }
            )
    }

    private func startListeningToRuuviTagsAlertStatus() {
        ruuviTags.forEach { ruuviTag in
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
    }

    private func openTagSettingsScreens(viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
            router.openTagSettings(
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement,
                sensorSettings: sensorSettingsList
                    .first(where: {
                        ($0.luid != nil && $0.luid?.any == viewModel.luid)
                            || ($0.macId != nil && $0.macId?.any == viewModel.mac)
                    }),
                output: self
            )
        }
    }

    private func openTagSettingsForNewSensor(viewModel: CardsViewModel) {
        if let ruuviTag = ruuviTags.first(where: { $0.id == viewModel.id }) {
            router.openTagSettings(
                with: viewModels,
                ruuviTagSensors: ruuviTags,
                sensorSettings: sensorSettingsList,
                scrollTo: viewModel,
                ruuviTag: ruuviTag,
                latestMeasurement: viewModel.latestMeasurement,
                sensorSetting: sensorSettingsList
                    .first(where: {
                        ($0.luid != nil && $0.luid?.any == viewModel.luid)
                            || ($0.macId != nil && $0.macId?.any == viewModel.mac)
                    }),
                output: self
            )
        }
    }

    private func openCardView(viewModel: CardsViewModel, showCharts: Bool) {
        router.openCardImageView(
            with: viewModels,
            ruuviTagSensors: ruuviTags,
            sensorSettings: sensorSettingsList,
            scrollTo: viewModel,
            showCharts: showCharts,
            output: self
        )
    }

    private func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter
            .default
            .addObserver(
                forName: .DidOpenWithUniversalLink,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    guard let self,
                          let userInfo = notification.userInfo
                    else {
                        guard let email = self?.ruuviUser.email else { return }
                        self?.view?.showAlreadyLoggedInAlert(with: email)
                        return
                    }
                    processLink(userInfo)
                }
            )
    }

    private func processLink(_ userInfo: [AnyHashable: Any]) {
        guard let path = userInfo["path"] as? UniversalLinkType,
              path == .dashboard,
              !ruuviUser.isAuthorized else { return }
        router.openSignIn(output: self)
    }

    private func startObservingCloudModeNotification() {
        cloudModeToken?.invalidate()
        cloudModeToken = NotificationCenter
            .default
            .addObserver(
                forName: .CloudModeDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.handleCloudModeState()
                }
            )
    }

    /// The method handles all the operations when cloud mode toggle is turned on/off
    private func handleCloudModeState() {
        // Disconnect the owned cloud tags
        removeConnectionsForCloudTags()
        // Restart observing
        restartObserveRuuviTagAdvertisements()
        observeRuuviTagHeartbeats()
        syncViewModels()
    }

    private func removeConnectionsForCloudTags() {
        connectionPersistence.keepConnectionUUIDs.filter { luid -> Bool in
            ruuviTags.filter(\.isCloud).contains(where: {
                $0.luid?.any != nil && $0.luid?.any == luid
            })
        }.forEach { luid in
            connectionPersistence.setKeepConnection(false, for: luid)
        }
    }

    // swiftlint:disable:next function_body_length
    private func startListeningToSettings() {
        temperatureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureUnitDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
            }
        temperatureAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .TemperatureAccuracyDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.syncAppSettingsToAppGroupContainer()
            }
        humidityUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        humidityAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .HumidityAccuracyDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        pressureUnitToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        pressureAccuracyToken = NotificationCenter
            .default
            .addObserver(
                forName: .PressureUnitAccuracyChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        languageToken = NotificationCenter
            .default
            .addObserver(
                forName: .LanguageDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        widgetRefreshIntervalToken = NotificationCenter
            .default
            .addObserver(
                forName: .WidgetRefreshIntervalDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.syncAppSettingsToAppGroupContainer()
                }
            )
        systemLanguageChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: NSLocale.currentLocaleDidChangeNotification,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.systemLocaleDidChange()
                }
            )
        dashboardTypeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DashboardTypeDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let type = userInfo[DashboardTypeKey.type] as? DashboardType {
                        self?.view?.dashboardType = type
                    }
                }
            )

        dashboardTapActionTypeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DashboardTapActionTypeDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] notification in
                    if let userInfo = notification.userInfo,
                       let type = userInfo[DashboardTapActionTypeKey.type] as?
                       DashboardTapActionType {
                        self?.view?.dashboardTapActionType = type
                    }
                }
            )
    }

    private func startObservingCloudSyncSuccessTokenState() {
        cloudSyncSuccessStateToken?.invalidate()
        cloudSyncSuccessStateToken = nil
        cloudSyncSuccessStateToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncDidComplete,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.triggerAlertsIfNeeded()
                }
            )
    }

    private func startObservingCloudSyncFailTokenState() {
        cloudSyncFailStateToken?.invalidate()
        cloudSyncFailStateToken = nil
        cloudSyncFailStateToken = NotificationCenter
            .default
            .addObserver(
                forName: .NetworkSyncDidFailForAuthorization,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    self?.forceLogoutUser()
                }
            )
    }

    private func startObservingSensorOrderChanges() {
        sensorOrderChangeToken?.invalidate()
        sensorOrderChangeToken = nil
        sensorOrderChangeToken = NotificationCenter
            .default
            .addObserver(
                forName: .DashboardSensorOrderDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.view?.dashboardSortingType = self.dashboardSortingType()
                        self.viewModels = self.reorder(self.viewModels)
                    }
                }
            )
    }

    @objc private func systemLocaleDidChange() {
        syncAppSettingsToAppGroupContainer()
    }

    private func askAppStoreReview(with sensorsCount: Int) {
        guard let dayDifference = Calendar.current.dateComponents(
            [.day],
            from: FileManager().appInstalledDate,
            to: Date()
        ).day, dayDifference > 7,
            sensorsCount > 0
        else {
            return
        }
        AppStoreReviewHelper.askForReview(settings: settings)
    }

    private func startObserveCalibrationSettingsChange() {
        calibrationSettingsToken = NotificationCenter
            .default
            .addObserver(
                forName: .SensorCalibrationDidChange,
                object: nil,
                queue: .main,
                using: { [weak self] _ in
                    guard let sSelf = self else { return }
                    sSelf.restartObservingRuuviTagLastRecords()
                }
            )
    }

    private func checkFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let sSelf = self else { return }
            sSelf.interactor.checkAndUpdateFirmwareVersion(for: ruuviTag)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func syncAlerts(ruuviTag: PhysicalSensor, viewModel: CardsViewModel) {
        AlertType.allCases.forEach { type in
            switch type {
            case .temperature:
                sync(temperature: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .relativeHumidity:
                sync(relativeHumidity: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pressure:
                sync(pressure: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .signal:
                sync(signal: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .carbonDioxide:
                sync(carbonDioxide: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter1:
                sync(pMatter1: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter2_5:
                sync(pMatter2_5: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter4:
                sync(pMatter4: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .pMatter10:
                sync(pMatter10: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .voc:
                sync(voc: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .nox:
                sync(nox: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .sound:
                sync(sound: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .luminosity:
                sync(luminosity: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .connection:
                sync(connection: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .movement:
                sync(movement: type, ruuviTag: ruuviTag, viewModel: viewModel)
            case .cloudConnection:
                sync(cloudConnection: type, ruuviTag: ruuviTag, viewModel: viewModel)
            default:
                break
            }

            let alertStates = [
                viewModel.temperatureAlertState,
                viewModel.relativeHumidityAlertState,
                viewModel.pressureAlertState,
                viewModel.signalAlertState,
                viewModel.carbonDioxideAlertState,
                viewModel.pMatter1AlertState,
                viewModel.pMatter2_5AlertState,
                viewModel.pMatter4AlertState,
                viewModel.pMatter10AlertState,
                viewModel.vocAlertState,
                viewModel.noxAlertState,
                viewModel.soundAlertState,
                viewModel.luminosityAlertState,
                viewModel.connectionAlertState,
                viewModel.movementAlertState,
                viewModel.cloudConnectionAlertState,
            ]

            if alertService.hasRegistrations(for: ruuviTag) {
                if alertStates.first(where: { alert in
                    alert == .firing
                }) != nil {
                    viewModel.alertState = .firing
                } else {
                    viewModel.alertState = .registered
                }
            } else {
                viewModel.alertState = .empty
            }
        }
    }

    private func sync(
        temperature: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .temperature = alertService
            .alert(for: ruuviTag, of: temperature) {
            viewModel.isTemperatureAlertOn = true
        } else {
            viewModel.isTemperatureAlertOn = false
        }
        viewModel.temperatureAlertMutedTill = alertService
            .mutedTill(
                type: temperature,
                for: ruuviTag
            )
    }

    private func sync(
        relativeHumidity: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .relativeHumidity = alertService.alert(
            for: ruuviTag,
            of: relativeHumidity
        ) {
            viewModel.isRelativeHumidityAlertOn = true
        } else {
            viewModel.isRelativeHumidityAlertOn = false
        }
        viewModel.relativeHumidityAlertMutedTill = alertService
            .mutedTill(
                type: relativeHumidity,
                for: ruuviTag
            )
    }

    private func sync(
        pressure: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pressure = alertService.alert(for: ruuviTag, of: pressure) {
            viewModel.isPressureAlertOn = true
        } else {
            viewModel.isPressureAlertOn = false
        }
        viewModel.pressureAlertMutedTill = alertService
            .mutedTill(
                type: pressure,
                for: ruuviTag
            )
    }

    private func sync(
        signal: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .signal = alertService.alert(for: ruuviTag, of: signal) {
            viewModel.isSignalAlertOn = true
        } else {
            viewModel.isSignalAlertOn = false
        }
        viewModel.signalAlertMutedTill =
            alertService.mutedTill(
                type: signal,
                for: ruuviTag
            )
    }

    private func sync(
        carbonDioxide: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .carbonDioxide = alertService
            .alert(for: ruuviTag, of: carbonDioxide) {
            viewModel.isCarbonDioxideAlertOn = true
        } else {
            viewModel.isCarbonDioxideAlertOn = false
        }
        viewModel.carbonDioxideAlertMutedTill =
            alertService.mutedTill(
                type: carbonDioxide,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter1: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter1 = alertService
            .alert(for: ruuviTag, of: pMatter1) {
            viewModel.isPMatter1AlertOn = true
        } else {
            viewModel.isPMatter1AlertOn = false
        }
        viewModel.pMatter1AlertMutedTill =
            alertService.mutedTill(
                type: pMatter1,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter2_5: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter2_5 = alertService
            .alert(for: ruuviTag, of: pMatter2_5) {
            viewModel.isPMatter2_5AlertOn = true
        } else {
            viewModel.isPMatter2_5AlertOn = false
        }
        viewModel.pMatter2_5AlertMutedTill =
            alertService.mutedTill(
                type: pMatter2_5,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter4: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter4 = alertService
            .alert(for: ruuviTag, of: pMatter4) {
            viewModel.isPMatter4AlertOn = true
        } else {
            viewModel.isPMatter4AlertOn = false
        }
        viewModel.pMatter4AlertMutedTill =
            alertService.mutedTill(
                type: pMatter4,
                for: ruuviTag
            )
    }

    private func sync(
        pMatter10: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .pMatter10 = alertService
            .alert(for: ruuviTag, of: pMatter10) {
            viewModel.isPMatter10AlertOn = true
        } else {
            viewModel.isPMatter10AlertOn = false
        }
        viewModel.pMatter10AlertMutedTill =
            alertService.mutedTill(
                type: pMatter10,
                for: ruuviTag
            )
    }

    private func sync(
        voc: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .voc = alertService.alert(for: ruuviTag, of: voc) {
            viewModel.isVOCAlertOn = true
        } else {
            viewModel.isVOCAlertOn = false
        }
        viewModel.vocAlertMutedTill =
            alertService.mutedTill(
                type: voc,
                for: ruuviTag
            )
    }

    private func sync(
        nox: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .nox = alertService.alert(for: ruuviTag, of: nox) {
            viewModel.isNOXAlertOn = true
        } else {
            viewModel.isNOXAlertOn = false
        }
        viewModel.noxAlertMutedTill =
            alertService.mutedTill(
                type: nox,
                for: ruuviTag
            )
    }

    private func sync(
        sound: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .sound = alertService.alert(for: ruuviTag, of: sound) {
            viewModel.isSignalAlertOn = true
        } else {
            viewModel.isSoundAlertOn = false
        }
        viewModel.soundAlertMutedTill =
            alertService.mutedTill(
                type: sound,
                for: ruuviTag
            )
    }

    private func sync(
        luminosity: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .luminosity = alertService.alert(for: ruuviTag, of: luminosity) {
            viewModel.isLuminosityAlertOn = true
        } else {
            viewModel.isLuminosityAlertOn = false
        }
        viewModel.luminosityAlertMutedTill =
            alertService.mutedTill(
                type: luminosity,
                for: ruuviTag
            )
    }

    private func sync(
        connection: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .connection = alertService.alert(for: ruuviTag, of: connection) {
            viewModel.isConnectionAlertOn = true
        } else {
            viewModel.isConnectionAlertOn = false
        }
        viewModel.connectionAlertMutedTill = alertService
            .mutedTill(
                type: connection,
                for: ruuviTag
            )
    }

    private func sync(
        movement: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .movement = alertService.alert(for: ruuviTag, of: movement) {
            viewModel.isMovementAlertOn = true
        } else {
            viewModel.isMovementAlertOn = false
        }
        viewModel.movementAlertMutedTill = alertService
            .mutedTill(
                type: movement,
                for: ruuviTag
            )
    }

    private func sync(
        cloudConnection: AlertType,
        ruuviTag: PhysicalSensor,
        viewModel: CardsViewModel
    ) {
        if case .cloudConnection = alertService.alert(for: ruuviTag, of: cloudConnection) {
            viewModel.isCloudConnectionAlertOn = true
        } else {
            viewModel.isCloudConnectionAlertOn = false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func reloadMutedTill() {
        for viewModel in viewModels {
            if let mutedTill = viewModel.temperatureAlertMutedTill,
               mutedTill < Date() {
                viewModel.temperatureAlertMutedTill = nil
            }

            if let mutedTill = viewModel.relativeHumidityAlertMutedTill,
               mutedTill < Date() {
                viewModel.relativeHumidityAlertMutedTill = nil
            }

            if let mutedTill = viewModel.pressureAlertMutedTill,
               mutedTill < Date() {
                viewModel.pressureAlertMutedTill = nil
            }

            if let mutedTill = viewModel.signalAlertMutedTill,
               mutedTill < Date() {
                viewModel.signalAlertMutedTill = nil
            }

            if let mutedTill = viewModel.carbonDioxideAlertMutedTill,
               mutedTill < Date() {
                viewModel.carbonDioxideAlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter1AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter1AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter2_5AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter2_5AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter4AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter4AlertMutedTill = nil
            }

            if let mutedTill = viewModel.pMatter10AlertMutedTill,
               mutedTill < Date() {
                viewModel.pMatter10AlertMutedTill = nil
            }

            if let mutedTill = viewModel.vocAlertMutedTill,
               mutedTill < Date() {
                viewModel.vocAlertMutedTill = nil
            }

            if let mutedTill = viewModel.noxAlertMutedTill,
               mutedTill < Date() {
                viewModel.noxAlertMutedTill = nil
            }

            if let mutedTill = viewModel.soundAlertMutedTill,
               mutedTill < Date() {
                viewModel.soundAlertMutedTill = nil
            }

            if let mutedTill = viewModel.luminosityAlertMutedTill,
               mutedTill < Date() {
                viewModel.luminosityAlertMutedTill = nil
            }

            if let mutedTill = viewModel.connectionAlertMutedTill,
               mutedTill < Date() {
                viewModel.connectionAlertMutedTill = nil
            }

            if let mutedTill = viewModel.movementAlertMutedTill,
               mutedTill < Date() {
                viewModel.movementAlertMutedTill = nil
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateMutedTill(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let date = alertService.mutedTill(type: type, for: uuid)

        switch type {
        case .temperature:
            viewModel.temperatureAlertMutedTill = date
        case .relativeHumidity:
            viewModel.relativeHumidityAlertMutedTill = date
        case .pressure:
            viewModel.pressureAlertMutedTill = date
        case .signal:
            viewModel.signalAlertMutedTill = date
        case .carbonDioxide:
            viewModel.carbonDioxideAlertMutedTill = date
        case .pMatter1:
            viewModel.pMatter1AlertMutedTill = date
        case .pMatter2_5:
            viewModel.pMatter2_5AlertMutedTill = date
        case .pMatter4:
            viewModel.pMatter4AlertMutedTill = date
        case .pMatter10:
            viewModel.pMatter10AlertMutedTill = date
        case .voc:
            viewModel.vocAlertMutedTill = date
        case .nox:
            viewModel.noxAlertMutedTill = date
        case .sound:
            viewModel.soundAlertMutedTill = date
        case .luminosity:
            viewModel.luminosityAlertMutedTill = date
        case .connection:
            viewModel.connectionAlertMutedTill = date
        case .movement:
            viewModel.movementAlertMutedTill = date
        default:
            // Should never be here
            viewModel.temperatureAlertMutedTill = date
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateIsOnState(
        of type: AlertType,
        for uuid: String,
        viewModel: CardsViewModel
    ) {
        let isOn = alertService.isOn(type: type, for: uuid)

        switch type {
        case .temperature:
            viewModel.isTemperatureAlertOn = isOn
        case .relativeHumidity:
            viewModel.isRelativeHumidityAlertOn = isOn
        case .pressure:
            viewModel.isPressureAlertOn = isOn
        case .signal:
            viewModel.isSignalAlertOn = isOn
        case .carbonDioxide:
            viewModel.isCarbonDioxideAlertOn = isOn
        case .pMatter1:
            viewModel.isPMatter1AlertOn = isOn
        case .pMatter2_5:
            viewModel.isPMatter2_5AlertOn = isOn
        case .pMatter4:
            viewModel.isPMatter4AlertOn = isOn
        case .pMatter10:
            viewModel.isPMatter10AlertOn = isOn
        case .voc:
            viewModel.isVOCAlertOn = isOn
        case .nox:
            viewModel.isNOXAlertOn = isOn
        case .sound:
            viewModel.isSoundAlertOn = isOn
        case .luminosity:
            viewModel.isLuminosityAlertOn = isOn
        case .connection:
            viewModel.isConnectionAlertOn = isOn
        case .movement:
            viewModel.isMovementAlertOn = isOn
        case .cloudConnection:
            viewModel.isCloudConnectionAlertOn = isOn
        default:
            // Should never be here, but fallback:
            viewModel.isTemperatureAlertOn = isOn
        }
    }

    /// Log out user if the auth token is expired.
    private func forceLogoutUser() {
        guard ruuviUser.isAuthorized else { return }
        activityPresenter.show(with: .loading(message: nil))
        if let token = pnManager.fcmToken, !token.isEmpty {
            cloudNotificationService.unregister(
                token: pnManager.fcmToken,
                tokenId: nil
            ).on(success: { [weak self] _ in
                self?.pnManager.fcmToken = nil
                self?.pnManager.fcmTokenLastRefreshed = nil
            })
        }

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
                self?.activityPresenter.dismiss()
            })
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }

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

    private func triggerAlertsIfNeeded() {
        for viewModel in viewModels {
            if let latestRecord = viewModel.latestMeasurement {
                guard let macId = viewModel.mac
                else {
                    continue
                }
                alertHandler.processNetwork(
                    record: latestRecord,
                    trigger: false, for: macId
                )
            }
        }
    }

    private func dashboardSortingType() -> DashboardSortingType {
        return settings.dashboardSensorOrder.count == 0 ? .alphabetical : .manual
    }

    private func triggerFullHistorySync() {
        if settings.historySyncOnDashboard &&
            (!settings.historySyncLegacy ||
             !settings.historySyncForEachSensor) {
            cloudSyncService.syncAllHistory()
        }
    }

    private func currentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// swiftlint:enable file_length
