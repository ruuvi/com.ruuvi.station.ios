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

// MARK: - DashboardPresenterRefactored
class DashboardPresenterRefactored: DashboardModuleInput {
    // MARK: - Dependencies
    weak var view: DashboardViewInput?
    var router: DashboardRouterInput!
    var interactor: DashboardInteractorInput!
    var serviceCoordinator: DashboardServiceCoordinatorProtocol!
    
    // Reduced dependencies - only what's needed for presentation logic
    var errorPresenter: ErrorPresenter!
    var permissionPresenter: PermissionPresenter!
    var pushNotificationsManager: RuuviCorePN!
    var permissionsManager: RuuviCorePermission!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var settings: RuuviLocalSettings!
    var ruuviSensorPropertiesService: RuuviServiceSensorProperties!
    var activityPresenter: ActivityPresenter!
    
    // MARK: - Private Properties
    private var universalLinkObservationToken: NSObjectProtocol?
    private var backgroundToken: NSObjectProtocol?
    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }
    
    deinit {
        stopObservations()
    }
}

// MARK: - DashboardViewOutput
extension DashboardPresenterRefactored: DashboardViewOutput {
    func start() {
        setupServiceObservations()
        serviceCoordinator.startServices()
        pushNotificationsManager.registerForRemoteNotifications()
    }

    func viewDidLoad() {
        setupServiceObservations()
        serviceCoordinator.startServices()
        pushNotificationsManager.registerForRemoteNotifications()
    }

    func viewWillAppear() {
        startObservingUniversalLinks()
        startObservingBackgroundChanges()
        syncAppSettingsToAppGroupContainer()
    }

    func viewWillDisappear() {
        // View will disappear handling
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
        handleSettingsNavigation(for: viewModel)
    }

    func viewDidTriggerChart(for viewModel: CardsViewModel) {
        handleChartNavigation(for: viewModel)
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
        handleBackgroundChange(for: viewModel)
    }

    func viewDidTriggerRename(for viewModel: CardsViewModel) {
        view?.showSensorNameRenameDialog(
            for: viewModel,
            sortingType: dashboardSortingType()
        )
    }

    func viewDidTriggerShare(for viewModel: CardsViewModel) {
        handleShare(for: viewModel)
    }

    func viewDidTriggerRemove(for viewModel: CardsViewModel) {
        handleRemove(for: viewModel)
    }

    func viewDidDismissKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        handleKeepConnectionDismissalChart(for: viewModel)
    }

    func viewDidConfirmToKeepConnectionChart(to viewModel: CardsViewModel) {
        handleKeepConnectionConfirmationChart(for: viewModel)
    }

    func viewDidDismissKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        handleKeepConnectionDismissalSettings(for: viewModel)
    }

    func viewDidConfirmToKeepConnectionSettings(to viewModel: CardsViewModel) {
        handleKeepConnectionConfirmationSettings(for: viewModel)
    }

    func viewDidChangeDashboardType(dashboardType: DashboardType) {
        if settings.dashboardType == dashboardType { return }
        
        view?.dashboardType = dashboardType
        settings.dashboardType = dashboardType
    }

    func viewDidChangeDashboardTapAction(type: DashboardTapActionType) {
        settings.dashboardTapActionType = type
        view?.dashboardTapActionType = type
    }

    func viewDidTriggerPullToRefresh() {
        serviceCoordinator.refreshCloudSync()
    }

    func viewDidRenameTag(to name: String, viewModel: CardsViewModel) {
        if let id = viewModel.id {
            serviceCoordinator.updateSensorName(name, for: id)
        }
        
        // Update sensor properties via service
        if let sensor = findSensor(for: viewModel) {
            ruuviSensorPropertiesService.set(name: name, for: sensor)
                .on(failure: { [weak self] error in
                    self?.errorPresenter.present(error: error)
                })
        }
    }

    func viewDidReorderSensors(
        with type: DashboardSortingType,
        orderedIds: [String]
    ) {
        settings.dashboardSensorOrder = orderedIds
        serviceCoordinator.reorderSensors(with: type, orderedIds: orderedIds)
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

// MARK: - Private Methods
private extension DashboardPresenterRefactored {
    func setupServiceObservations() {
        // Set initial values from service coordinator
        view?.viewModels = serviceCoordinator.viewModels
        view?.shouldShowSignInBanner = serviceCoordinator.shouldShowSignInBanner
        view?.showNoSensorsAddedMessage(show: serviceCoordinator.noSensorsMessage)
        handleBluetoothStateChange(serviceCoordinator.bluetoothState)
        
        // Setup callbacks for service coordinator changes
        serviceCoordinator.onViewModelsChanged = { [weak self] viewModels in
            DispatchQueue.main.async {
                self?.view?.viewModels = viewModels
            }
        }
        
        serviceCoordinator.onShouldShowSignInBannerChanged = { [weak self] shouldShow in
            DispatchQueue.main.async {
                self?.view?.shouldShowSignInBanner = shouldShow
            }
        }
        
        serviceCoordinator.onNoSensorsMessageChanged = { [weak self] shouldShow in
            DispatchQueue.main.async {
                self?.view?.showNoSensorsAddedMessage(show: shouldShow)
            }
        }
        
        serviceCoordinator.onBluetoothStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleBluetoothStateChange(state)
            }
        }
        
        serviceCoordinator.onCloudModeChanged = { [weak self] isCloudModeEnabled in
            DispatchQueue.main.async {
                // Handle cloud mode changes if needed
            }
        }
    }
    
    func handleBluetoothStateChange(_ state: BTScannerState) {
        if state != .poweredOn || !isBluetoothPermissionGranted {
            view?.showBluetoothDisabled(userDeclined: !isBluetoothPermissionGranted)
        }
    }
    
    func handleSettingsNavigation(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi {
            if let luid = viewModel.luid {
                if settings.keepConnectionDialogWasShown(for: luid)
                    || serviceCoordinator.isConnected(uuid: luid.value)
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
    
    func handleChartNavigation(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            if settings.keepConnectionDialogWasShown(for: luid)
                || serviceCoordinator.isConnected(uuid: luid.value)
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
    
    func handleBackgroundChange(for viewModel: CardsViewModel) {
        if viewModel.type == .ruuvi,
           let sensor = findSensor(for: viewModel) {
            router.openBackgroundSelectionView(ruuviTag: sensor)
        }
    }
    
    func handleShare(for viewModel: CardsViewModel) {
        if let sensor = findSensor(for: viewModel) {
            router.openShare(for: sensor)
        }
    }
    
    func handleRemove(for viewModel: CardsViewModel) {
        if let sensor = findSensor(for: viewModel) {
            router.openRemove(for: sensor, output: self)
        }
    }
    
    func handleKeepConnectionDismissalChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func handleKeepConnectionConfirmationChart(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            serviceCoordinator.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openCardView(viewModel: viewModel, showCharts: true)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func handleKeepConnectionDismissalSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func handleKeepConnectionConfirmationSettings(for viewModel: CardsViewModel) {
        if let luid = viewModel.luid {
            serviceCoordinator.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            openTagSettingsScreens(viewModel: viewModel)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }
    
    func openCardView(viewModel: CardsViewModel, showCharts: Bool) {
        // Implementation would need access to current sensors and settings
        // This would be coordinated through the service coordinator
        router.openCardImageView(
            with: view?.viewModels ?? [],
            ruuviTagSensors: [], // Would need to get from service
            sensorSettings: [], // Would need to get from service
            scrollTo: viewModel,
            showCharts: showCharts,
            output: self
        )
    }
    
    func openTagSettingsScreens(viewModel: CardsViewModel) {
        if let sensor = findSensor(for: viewModel) {
            router.openTagSettings(
                ruuviTag: sensor,
                latestMeasurement: viewModel.latestMeasurement,
                sensorSettings: nil, // Would get from service
                output: self
            )
        }
    }
    
    func findSensor(for viewModel: CardsViewModel) -> AnyRuuviTagSensor? {
        return serviceCoordinator.ruuviTags.first(
            where: { $0.id == viewModel.id })
    }
    
    func dashboardSortingType() -> DashboardSortingType {
        return settings.dashboardSensorOrder.isEmpty ? .alphabetical : .manual
    }
    
    func syncAppSettingsToAppGroupContainer() {
        // Delegate to service
        // This would be handled by SettingsObservationService
    }
    
    func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter.default.addObserver(
            forName: .UniversalLinkDidReceive,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleUniversalLink(notification)
        }
    }
    
    func startObservingBackgroundChanges() {
        backgroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAppSettingsToAppGroupContainer()
        }
    }
    
    func stopObservations() {
        universalLinkObservationToken?.invalidate()
        backgroundToken?.invalidate()
        
        // Clear service coordinator callbacks
        serviceCoordinator.onViewModelsChanged = nil
        serviceCoordinator.onShouldShowSignInBannerChanged = nil
        serviceCoordinator.onNoSensorsMessageChanged = nil
        serviceCoordinator.onBluetoothStateChanged = nil
        serviceCoordinator.onCloudModeChanged = nil
        serviceCoordinator.onSyncStatusChanged = nil
        
        serviceCoordinator.stopServices()
    }
    
    func handleUniversalLink(_ notification: Notification) {
        // Handle universal link logic
    }
    
    func currentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Module Output Extensions
extension DashboardPresenterRefactored: MenuModuleOutput {
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

extension DashboardPresenterRefactored: SignInBenefitsModuleOutput {
    func signIn(
        module: SignInBenefitsModuleInput,
        didSuccessfulyLogin _: Any?
    ) {
        serviceCoordinator.refreshCloudSync()
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

extension DashboardPresenterRefactored: DiscoverRouterDelegate {
    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true)
    }

    func discoverRouterWantsCloseWithRuuviTagNavigation(
        _ router: DiscoverRouter,
        ruuviTag: RuuviTagSensor
    ) {
        router.viewController.dismiss(animated: true)
        if let viewModel = view?.viewModels.first(
            where: { $0.id == ruuviTag.id
            }) {
            openCardView(viewModel: viewModel, showCharts: false)
        }
    }
}

extension DashboardPresenterRefactored: DashboardRouterDelegate {
    func shouldDismissDiscover() -> Bool {
        return (view?.viewModels.count ?? 0) > 0
    }
}

extension DashboardPresenterRefactored: CardsModuleOutput {
    func cardsViewDidDismiss(module: CardsModuleInput) {
        module.dismiss(completion: nil)
    }

    func cardsViewDidRefresh(module _: CardsModuleInput) {
        // No op.
    }
}

extension DashboardPresenterRefactored: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag _: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            // Sensors will be automatically updated via service observation
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

extension DashboardPresenterRefactored: SensorRemovalModuleOutput {
    func sensorRemovalDidRemoveTag(
        module: SensorRemovalModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            // Sensors will be automatically updated via service observation
        })
    }

    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let UniversalLinkDidReceive = Notification.Name("UniversalLinkDidReceive")
}
