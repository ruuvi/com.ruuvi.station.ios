// swiftlint:disable file_length

import Foundation
import UIKit
import RuuviOntology
import RuuviService
import RuuviLocal
import RuuviCore
import RuuviDaemon
import RuuviReactor
import RuuviUser
import RuuviNotifier
import BTKit
import RuuviPresenters

class DashboardPresenter {

    // MARK: - View and Router
    weak var view: NewDashboardViewInput?
    var router: DashboardRouterInput!
    var interactor: DashboardInteractorInput!
    var errorPresenter: ErrorPresenter!

    // MARK: - Services
    private let settingsService: DashboardSettingsService
    private let serviceCoordinatorManager: RuuviTagServiceCoordinatorManager

    // MARK: - Additional Dependencies
    var permissionPresenter: PermissionPresenter!
    var pushNotificationsManager: RuuviCorePN!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var activityPresenter: ActivityPresenter!
    var flags: RuuviLocalFlags!

    // MARK: - Observation Tokens
    private var universalLinkObservationToken: NSObjectProtocol?
    private var backgroundChangeToken: NSObjectProtocol?
    private var connectionChangeToken: NSObjectProtocol?
    private var daemonFailureTokens: [NSObjectProtocol] = []

    // MARK: - State
    private var didLoadInitialSensors = false

    // MARK: - Initialization
    init(
        settingsService: DashboardSettingsService,
        serviceCoordinatorManager: RuuviTagServiceCoordinatorManager = .shared
    ) {
        self.settingsService = settingsService
        self.serviceCoordinatorManager = serviceCoordinatorManager

        setupServiceDelegates()
    }

    deinit {
        stopAllObservations()
    }

    // MARK: - Setup
    private func setupServiceDelegates() {
        settingsService.delegate = self
    }

    private func startAllServices() {
        settingsService.startObservingSettings()
        serviceCoordinatorManager.addObserver(self)

        startObservingUniversalLinks()
        startObservingDaemonErrors()
        startObservingConnectionChanges()
    }

    private func stopAllObservations() {
        settingsService.stopObservingSettings()

        serviceCoordinatorManager.removeObserver(self)

        universalLinkObservationToken?.invalidate()
        backgroundChangeToken?.invalidate()
        connectionChangeToken?.invalidate()
        daemonFailureTokens.forEach { $0.invalidate() }

        universalLinkObservationToken = nil
        backgroundChangeToken = nil
        connectionChangeToken = nil
        daemonFailureTokens.removeAll()
    }
}

// MARK: - DashboardViewOutput
extension DashboardPresenter: DashboardViewOutput {

    func viewDidLoad() {
        serviceCoordinatorManager.initialize()
        startAllServices()
        serviceCoordinatorManager.triggerFullHistorySync()
        pushNotificationsManager.registerForRemoteNotifications()
    }

    func viewWillAppear() {
        updateViewSettings()
        let isAuthorized = serviceCoordinatorManager.isCloudAuthorized()
        view?.isAuthorized = isAuthorized
        settingsService.syncAppSettingsToAppGroupContainer(isAuthorized: isAuthorized)
    }

    func viewWillDisappear() {
        // No op.
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

    func viewDidTriggerSettings(for snapshot: RuuviTagCardSnapshot) {
        viewDidAskToOpenSensorSettings(for: snapshot, isNewlyAdded: false)
    }

    func viewDidTriggerChart(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }

        let (isConnected, _ ) = serviceCoordinatorManager.getConnectionStatus(
            for: snapshot
        )
        let firmwareType      = RuuviDataFormat.dataFormat(
            from: snapshot.displayData.version.bound
        )
        let isAir             = firmwareType == .e1 || firmwareType == .v6

        if snapshot.identifierData.luid != nil {
            if settingsService.keepConnectionDialogWasShown(for: snapshot)
                || isAir
                || isConnected
                || !snapshot.connectionData.isConnectable
                || !snapshot.metadata.isOwner
                || (
                    serviceCoordinatorManager.isCloudModeEnabled() && snapshot.metadata.isCloud
                ) {
                openCardView(for: snapshot, sensor: sensor, showCharts: true)
            } else {
                view?.showKeepConnectionDialogChart(for: snapshot)
            }
        } else {
            openCardView(for: snapshot, sensor: sensor, showCharts: true)
        }
    }

    func viewDidTriggerOpenCardImageView(for snapshot: RuuviTagCardSnapshot?) {
        guard let snapshot = snapshot,
              let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }

        openCardView(for: snapshot, sensor: sensor, showCharts: false)
    }

    func viewDidTriggerOpenSensorCardFromWidget(for snapshot: RuuviTagCardSnapshot?) {
        guard let snapshot = snapshot,
              let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }

        let showCharts = settingsService.getDashboardTapActionType() == .chart
        openCardView(for: snapshot, sensor: sensor, showCharts: showCharts)
    }

    func viewDidTriggerDashboardCard(for snapshot: RuuviTagCardSnapshot) {
        if settingsService.showFullSensorCardOnDashboardTap() {
            viewDidTriggerOpenCardImageView(for: snapshot)
            settingsService.updateShowFullSensorCardOnDashboardTap(false)
            return
        }

        switch settingsService.getDashboardTapActionType() {
        case .card:
            viewDidTriggerOpenCardImageView(for: snapshot)
        case .chart:
            viewDidTriggerChart(for: snapshot)
        }
    }

    func viewDidTriggerChangeBackground(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        router.openBackgroundSelectionView(ruuviTag: sensor)
    }

    func viewDidTriggerRename(for snapshot: RuuviTagCardSnapshot) {
        view?.showSensorNameRenameDialog(
            for: snapshot,
            sortingType: settingsService.getCurrentDashboardSortingType()
        )
    }

    func viewDidTriggerShare(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        router.openShare(for: sensor)
    }

    func viewDidTriggerRemove(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        router.openRemove(for: sensor, output: self)
    }

    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        openCardView(for: snapshot, sensor: sensor, showCharts: true)
    }

    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot) {
        serviceCoordinatorManager.setKeepConnection(true, for: snapshot)
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        openCardView(for: snapshot, sensor: sensor, showCharts: true)
    }

    func viewDidDismissKeepConnectionDialogSettings(
        for snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    ) {
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        openTagSettings(
            for: snapshot,
            sensor: sensor,
            isNewlyAdded: newlyAddedSensor
        )
    }

    func viewDidConfirmToKeepConnectionSettings(
        to snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    ) {
        serviceCoordinatorManager.setKeepConnection(true, for: snapshot)
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else { return }
        openTagSettings(
            for: snapshot,
            sensor: sensor,
            isNewlyAdded: newlyAddedSensor
        )
    }

    func viewDidChangeDashboardType(dashboardType: DashboardType) {
        guard settingsService.getDashboardType() != dashboardType else { return }

        settingsService.updateDashboardType(dashboardType)
        view?.dashboardType = dashboardType
    }

    func viewDidChangeDashboardTapAction(type: DashboardTapActionType) {
        settingsService.updateDashboardTapAction(type)
        view?.dashboardTapActionType = type
    }

    func viewDidTriggerPullToRefresh() {
        serviceCoordinatorManager.triggerCloudSync()
    }

    func viewDidRenameTag(to name: String, snapshot: RuuviTagCardSnapshot) {
        serviceCoordinatorManager.updateSensorName(name, for: snapshot)
    }

    func viewDidReorderSensors(with type: DashboardSortingType, orderedIds: [String]) {
        settingsService.setUserActivelyDraggingCards(true)
        if type == .alphabetical {
            settingsService.resetSensorOrder()
        } else {
            settingsService.updateSensorOrder(orderedIds)
        }

        serviceCoordinatorManager.reorderSnapshots(with: orderedIds)
        view?.dashboardSortingType = settingsService.getCurrentDashboardSortingType()
        settingsService.setUserActivelyDraggingCards(false)
    }

    func viewDidResetManualSorting() {
        view?.showSensorSortingResetConfirmationDialog()
    }

    func viewDidHideSignInBanner() {
        settingsService.hideSignInBanner()
        view?.shouldShowSignInBanner = false
    }
}

// MARK: - Helper Methods
private extension DashboardPresenter {

    func coordinatorSnapshots() -> [RuuviTagCardSnapshot] {
        serviceCoordinatorManager.getAllSnapshots()
    }

    func coordinatorSensors() -> [AnyRuuviTagSensor] {
        serviceCoordinatorManager.getAllSensors()
    }

    func coordinatorSensorSettings() -> [SensorSettings] {
        serviceCoordinatorManager.getSensorSettings()
    }

    func coordinatorSensor(for snapshot: RuuviTagCardSnapshot) -> AnyRuuviTagSensor? {
        serviceCoordinatorManager.getSensor(for: snapshot.id)
    }

    func updateViewSettings() {
        view?.dashboardType = settingsService.getDashboardType()
        view?.dashboardTapActionType = settingsService.getDashboardTapActionType()
        view?.dashboardSortingType = settingsService.getCurrentDashboardSortingType()
    }

    func markKeepConnectionDialogShown(for snapshot: RuuviTagCardSnapshot) {
        settingsService.setKeepConnectionDialogWasShown(for: snapshot)
    }

    func handleSnapshotsUpdated(
        _ snapshots: [RuuviTagCardSnapshot],
        reason: SnapshotUpdateReason,
        withAnimation: Bool
    ) {
        view?.updateSnapshots(snapshots, withAnimation: withAnimation)
        view?.showNoSensorsAddedMessage(show: snapshots.isEmpty)

        if didLoadInitialSensors {
            settingsService.askAppStoreReview(with: snapshots.count)
        }
        didLoadInitialSensors = true

        updateSignInBannerVisibility(sensorCount: snapshots.count)

        let hasCloudSensors = snapshots.contains { $0.metadata.isCloud }
        settingsService.syncHasCloudSensorToAppGroupContainer(hasCloudSensors: hasCloudSensors)
    }

    func updateAuthorizationState() {
        let isAuthorized = serviceCoordinatorManager.isCloudAuthorized()
        view?.isAuthorized = isAuthorized
        settingsService.syncAppSettingsToAppGroupContainer(isAuthorized: isAuthorized)

        let sensorCount = coordinatorSnapshots().count
        updateSignInBannerVisibility(sensorCount: sensorCount)
    }

    func handleAlertsChanged(_ coordinator: RuuviTagServiceCoordinator) {
        let snapshots = coordinator.getAllSnapshots()
        coordinator.triggerAlertsIfNeeded(for: snapshots)
    }

    func handleCloudModeChanged(
        _ isEnabled: Bool,
        coordinator: RuuviTagServiceCoordinator
    ) {
        let snapshots = coordinator.getAllSnapshots()
        coordinator.services.connection.removeConnectionsForCloudSensors(snapshots: snapshots)
        restartServiceCoordinatorSensors()
        settingsService
            .syncAppSettingsToAppGroupContainer(
                isAuthorized: serviceCoordinatorManager.isCloudAuthorized()
            )
        updateSignInBannerVisibility(sensorCount: snapshots.count)
    }

    func handleAuthorizationFailed() {
        restartServiceCoordinatorSensors()
        updateAuthorizationState()
    }

    func restartServiceCoordinatorSensors() {
        serviceCoordinatorManager.withCoordinator { coordinator in
            coordinator.services.data.stopObservingSensors()
            coordinator.services.data.startObservingSensors()
        }
    }

    // When newSensor is True, sensor settings page is open as a child
    // view controller with full sensor card injected before the settings
    // so that user can come back to full sensor card using back button from
    // settings
    func viewDidAskToOpenSensorSettings(
        for snapshot: RuuviTagCardSnapshot,
        isNewlyAdded: Bool
    ) {
        guard let sensor = coordinatorSensor(for: snapshot) else { return }

        let (isConnected, _ ) = serviceCoordinatorManager.getConnectionStatus(for: snapshot)
        let firmwareType = RuuviDataFormat.dataFormat(
            from: snapshot.displayData.version.bound
        )
        let isAir = firmwareType == .e1 || firmwareType == .v6
        let cloudModeBypass = serviceCoordinatorManager.isCloudModeEnabled() && snapshot.metadata.isCloud

        if snapshot.identifierData.luid != nil {
            if settingsService.keepConnectionDialogWasShown(for: snapshot)
                || isAir
                || isConnected
                || !snapshot.connectionData.isConnectable
                || !snapshot.metadata.isOwner
                || cloudModeBypass {
                openTagSettings(
                    for: snapshot,
                    sensor: sensor,
                    isNewlyAdded: isNewlyAdded
                )
            } else {
                view?
                    .showKeepConnectionDialogSettings(
                        for: snapshot,
                        newlyAddedSensor: isNewlyAdded
                    )
            }
        } else {
            openTagSettings(
                for: snapshot,
                sensor: sensor,
                isNewlyAdded: isNewlyAdded
            )
        }
    }

    func openTagSettings(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor,
        isNewlyAdded: Bool = false
    ) {
        let sensorSettings = coordinatorSensorSettings()
        let relevantSetting = sensorSettings.first { setting in
            (setting.luid?.any != nil && setting.luid?.any == snapshot.identifierData.luid?.any) ||
            (setting.macId?.any != nil && setting.macId?.any == snapshot.identifierData.mac?.any)
        }

        if isNewlyAdded {
            let allSnapshots = coordinatorSnapshots()
            let allSensors = coordinatorSensors()

            if flags.showRedesignedCardsUIWithNewMenu {
                router.openFullSensorCard(
                    for: snapshot,
                    snapshots: allSnapshots,
                    ruuviTagSensors: allSensors,
                    sensorSettings: sensorSettings,
                    activeMenu: .settings,
                    openSettings: false
                )
            } else if flags.showRedesignedCardsUIWithoutNewMenu {
                router.openFullSensorCard(
                    for: snapshot,
                    snapshots: allSnapshots,
                    ruuviTagSensors: allSensors,
                    sensorSettings: sensorSettings,
                    activeMenu: .measurement,
                    openSettings: true
                )
            } else {
                let viewModel = createViewModelFromSnapshot(snapshot)
                let allViewModels = allSnapshots.compactMap { createViewModelFromSnapshot($0) }
                router
                    .openTagSettings(
                        with: allViewModels,
                        ruuviTagSensors: allSensors,
                        sensorSettings: sensorSettings,
                        scrollTo: viewModel,
                        ruuviTag: sensor,
                        latestMeasurement: snapshot.latestRawRecord,
                        sensorSetting: relevantSetting,
                        output: self
                    )
            }
        } else {
            router.openTagSettings(
                ruuviTag: sensor,
                latestMeasurement: snapshot.latestRawRecord,
                sensorSettings: relevantSetting,
                output: self
            )
        }
    }

    func openCardView(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor,
        showCharts: Bool
    ) {
        let allSnapshots = coordinatorSnapshots()
        let allSensors = coordinatorSensors()
        let sensorSettings = coordinatorSensorSettings()

        // Create CardsViewModel for backward compatibility with router
        let viewModel = createViewModelFromSnapshot(snapshot)
        let allViewModels = allSnapshots.compactMap { createViewModelFromSnapshot($0) }

        if flags.showRedesignedCardsUIWithNewMenu ||
            flags.showRedesignedCardsUIWithoutNewMenu {
            router.openFullSensorCard(
                for: snapshot,
                snapshots: allSnapshots,
                ruuviTagSensors: allSensors,
                sensorSettings: sensorSettings,
                activeMenu: showCharts ? .graph : .measurement,
                openSettings: false
            )
        } else {
            router.openCardImageView(
                with: allViewModels,
                ruuviTagSensors: allSensors,
                sensorSettings: sensorSettings,
                scrollTo: viewModel,
                showCharts: showCharts,
                output: self
            )
        }
    }

    func createViewModelFromSnapshot(_ snapshot: RuuviTagCardSnapshot) -> LegacyCardsViewModel {
        // Create a temporary CardsViewModel for backward compatibility
        // This should be removed once router is updated to use snapshots
        guard let sensor = serviceCoordinatorManager.getSensor(for: snapshot.id) else {
            fatalError("Sensor not found for snapshot")
        }
        let viewModel = LegacyCardsViewModel(sensor)
        viewModel.background = snapshot.displayData.background
        if let record = snapshot.latestRawRecord {
            viewModel.update(record)
        }
        return viewModel
    }
}

// MARK: - Observation Setup
private extension DashboardPresenter {

    func startObservingUniversalLinks() {
        universalLinkObservationToken = NotificationCenter.default.addObserver(
            forName: .DidOpenWithUniversalLink,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo else {
                if let email = self?.serviceCoordinatorManager.getUserEmail() {
                    self?.view?.showAlreadyLoggedInAlert(with: email)
                }
                return
            }
            self.processUniversalLink(userInfo)
        }
    }

    func startObservingDaemonErrors() {
        let daemonNotifications: [Notification.Name] = [
            .RuuviTagAdvertisementDaemonDidFail,
            .RuuviTagPropertiesDaemonDidFail,
            .RuuviTagHeartbeatDaemonDidFail,
            .RuuviTagReadLogsOperationDidFail,
        ]

        for notificationName in daemonNotifications {
            let token = NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let userInfo = notification.userInfo,
                   let error = userInfo.values.first as? Error {
                    self?.errorPresenter.present(error: error)
                }
            }
            daemonFailureTokens.append(token)
        }
    }

    func startObservingConnectionChanges() {
        connectionChangeToken = NotificationCenter.default.addObserver(
            forName: .DashboardConnectionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let uuid = userInfo["uuid"] as? String,
                  let isConnected = userInfo["isConnected"] as? Bool else { return }
            // Find snapshot by UUID and update connection status
            let snapshots = self.coordinatorSnapshots()
            if let snapshot = snapshots.first(where: { $0.identifierData.luid?.value == uuid }) {
                snapshot.updateConnectionData(
                    isConnected: isConnected,
                    isConnectable: snapshot.connectionData.isConnectable,
                    keepConnection: snapshot.connectionData.keepConnection
                )
                self.view?.updateSnapshot(from: snapshot)
            }
        }
    }

    func processUniversalLink(_ userInfo: [AnyHashable: Any]) {
        guard let path = userInfo["path"] as? UniversalLinkType,
              path == .dashboard,
              !serviceCoordinatorManager.isCloudAuthorized() else { return }

        router.openSignIn(output: self)
    }
}

// MARK: - Service Coordinator Observer
extension DashboardPresenter: RuuviTagServiceCoordinatorObserver {

    // swiftlint:disable:next cyclomatic_complexity
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        switch event {
        case .snapshotsUpdated(let snapshots, let reason, let withAnimation):
            handleSnapshotsUpdated(snapshots, reason: reason, withAnimation: withAnimation)

        case .snapshotUpdated(let snapshot, let invalidateLayout):
            view?.updateSnapshot(from: snapshot, invalidateLayout: invalidateLayout)

        case .newSensorAdded(let sensor, let newOrder):
            checkFirmwareVersion(for: sensor)
            if !newOrder.isEmpty {
                viewDidReorderSensors(with: .manual, orderedIds: newOrder)
            }
            if let snapshot = coordinator.getSnapshot(for: sensor.id) {
                viewDidAskToOpenSensorSettings(for: snapshot, isNewlyAdded: true)
            }

        case .dataServiceError(let error):
            errorPresenter.present(error: error)

        case .userLoginStateChanged:
            updateAuthorizationState()

        case .userLogoutStateChanged:
            updateAuthorizationState()

        case .cloudSyncStatusChanged(let isRefreshing):
            view?.isRefreshing = isRefreshing

        case .cloudSyncCompleted:
            handleAlertsChanged(coordinator)

        case .historySyncInProgress:
            break

        case .authorizationFailed:
            handleAuthorizationFailed()

        case .cloudModeChanged(let isEnabled):
            handleCloudModeChanged(isEnabled, coordinator: coordinator)

        case .alertSnapshotUpdated(let snapshot):
            view?.updateSnapshot(from: snapshot)

        case .alertsChanged:
            handleAlertsChanged(coordinator)

        case .connectionSnapshotUpdated(let snapshot):
            view?.updateSnapshot(from: snapshot)

        case .bluetoothStateChanged(let isEnabled, let userDeclined):
            let snapshots = coordinator.getAllSnapshots()
            if coordinator.shouldShowBluetoothAlert(for: snapshots) &&
                (!isEnabled || userDeclined) {
                view?.showBluetoothDisabled(userDeclined: userDeclined)
            }

        case .connectionServiceError(let error):
            errorPresenter.present(error: error)
        }
    }
}

extension DashboardPresenter: DashboardSettingsServiceDelegate {

    func settingsService(
        _ service: DashboardSettingsService,
        dashboardTypeDidChange type: DashboardType
    ) {
        view?.dashboardType = type
    }

    func settingsService(
        _ service: DashboardSettingsService,
        dashboardTapActionDidChange type: DashboardTapActionType
    ) {
        view?.dashboardTapActionType = type
    }

    func settingsService(
        _ service: DashboardSettingsService,
        sensorOrderDidChange: Bool
    ) {
        view?.dashboardSortingType = service
            .getCurrentDashboardSortingType()

        // Reorder snapshots
        let orderedIds = service.getSensorOrder()
        serviceCoordinatorManager
            .reorderSnapshots(
                with: orderedIds
            )
    }

    func settingsService(
        _ service: DashboardSettingsService,
        measurementUnitsDidChange: Bool
    ) {
        // Trigger view reload for unit changes
        let snapshots = coordinatorSnapshots()
        view?.updateSnapshots(snapshots, withAnimation: false)
    }

    func settingsService(
        _ service: DashboardSettingsService,
        calibrationSettingsDidChange: Bool
    ) {
        restartServiceCoordinatorSensors()
    }

    func settingsService(
        _ service: DashboardSettingsService,
        languageDidChange: Bool
    ) {
        // Trigger view reload for language changes
        let snapshots = coordinatorSnapshots()
        view?.updateSnapshots(snapshots, withAnimation: false)
    }
}

// MARK: - Module Outputs
extension DashboardPresenter: MenuModuleOutput {

    func menu(module: MenuModuleInput, didSelectAddRuuviTag: Any?) {
        module.dismiss()
        router.openDiscover(delegate: self)
    }

    func menu(module: MenuModuleInput, didSelectSettings: Any?) {
        module.dismiss()
        router.openSettings()
    }

    func menu(module: MenuModuleInput, didSelectAbout: Any?) {
        module.dismiss()
        router.openAbout()
    }

    func menu(module: MenuModuleInput, didSelectWhatToMeasure: Any?) {
        module.dismiss()
        router.openWhatToMeasurePage()
    }

    func menu(module: MenuModuleInput, didSelectGetMoreSensors: Any?) {
        module.dismiss()
        router.openRuuviProductsPageFromMenu()
    }

    func menu(module: MenuModuleInput, didSelectFeedback: Any?) {
        module.dismiss()
        infoProvider.summary { [weak self] summary in
            guard let self = self else { return }
            self.mailComposerPresenter.present(
                email: self.feedbackEmail,
                subject: self.feedbackSubject,
                body: "\n\n" + summary
            )
        }
    }

    func menu(module: MenuModuleInput, didSelectSignIn: Any?) {
        module.dismiss()
        router.openSignIn(output: self)
    }

    func menu(module: MenuModuleInput, didSelectOpenConfig: Any?) {
        module.dismiss()
    }

    func menu(module: MenuModuleInput, didSelectOpenMyRuuviAccount: Any?) {
        module.dismiss()
        router.openMyRuuviAccount()
    }
}

extension DashboardPresenter: SignInBenefitsModuleOutput {

    func signIn(module: SignInBenefitsModuleInput, didSuccessfulyLogin: Any?) {
        startAllServices()
        serviceCoordinatorManager.triggerFullHistorySync()
        serviceCoordinatorManager.forceReorderSnapshots()
        serviceCoordinatorManager.forceLoadBackgrounds()
        updateAuthorizationState()

        module.dismiss {
            AppUtility.lockOrientation(.all)
        }
    }

    func signIn(module: SignInBenefitsModuleInput, didCloseSignInWithoutAttempt: Any?) {
        module.dismiss {
            AppUtility.lockOrientation(.all)
        }
    }

    func signIn(module: SignInBenefitsModuleInput, didSelectUseWithoutAccount: Any?) {
        module.dismiss {
            AppUtility.lockOrientation(.all)
        }
    }
}

extension DashboardPresenter: DiscoverRouterDelegate {

    func discoverRouterWantsClose(_ router: DiscoverRouter) {
        router.viewController.dismiss(animated: true)
    }

    func discoverRouterWantsCloseWithRuuviTagNavigation(_ router: DiscoverRouter, ruuviTag: RuuviTagSensor) {
        router.viewController.dismiss(animated: true)

        if let snapshot = serviceCoordinatorManager.getSnapshot(for: ruuviTag.id) {
            openCardView(for: snapshot, sensor: ruuviTag.any, showCharts: false)
        }
    }
}

extension DashboardPresenter: DashboardRouterDelegate {

    func shouldDismissDiscover() -> Bool {
        return !serviceCoordinatorManager.getAllSnapshots().isEmpty
    }
}

extension DashboardPresenter: LegacyCardsModuleOutput {

    func cardsViewDidDismiss(module: LegacyCardsModuleInput) {
        module.dismiss(completion: nil)
    }

    func cardsViewDidRefresh(module: LegacyCardsModuleInput) {
        // No op.
    }
}

extension DashboardPresenter: TagSettingsModuleOutput {

    func tagSettingsDidDeleteTag(module: TagSettingsModuleInput, ruuviTag: RuuviTagSensor) {
        module.dismiss { [weak self] in
            self?.restartServiceCoordinatorSensors()
        }
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

extension DashboardPresenter: SensorRemovalModuleOutput {

    func sensorRemovalDidRemoveTag(module: SensorRemovalModuleInput, ruuviTag: RuuviTagSensor) {
        module.dismiss { [weak self] in
            self?.restartServiceCoordinatorSensors()
        }
    }

    func sensorRemovalDidDismiss(module: SensorRemovalModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: - Helper Methods
private extension DashboardPresenter {

    func updateSignInBannerVisibility(sensorCount: Int) {
        let shouldShow = settingsService.shouldShowSignInBanner(
            isAuthorized: serviceCoordinatorManager.isCloudAuthorized(),
            sensorCount: sensorCount
        )
        view?.shouldShowSignInBanner = shouldShow
    }

    func checkFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.interactor.checkAndUpdateFirmwareVersion(for: ruuviTag)
        }
    }
}

// swiftlint:enable file_length
