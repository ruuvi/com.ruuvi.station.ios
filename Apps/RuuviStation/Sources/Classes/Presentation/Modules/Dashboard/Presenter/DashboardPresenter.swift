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
    private let sensorDataService: RuuviTagDataService
    private let alertService: RuuviTagAlertService
    private let backgroundService: RuuviTagBackgroundService
    private let connectionService: RuuviTagConnectionService
    private let settingsService: DashboardSettingsService
    private let cloudSyncService: DashboardCloudSyncService

    // MARK: - Additional Dependencies
    var permissionPresenter: PermissionPresenter!
    var pushNotificationsManager: RuuviCorePN!
    var mailComposerPresenter: MailComposerPresenter!
    var feedbackEmail: String!
    var feedbackSubject: String!
    var infoProvider: InfoProvider!
    var activityPresenter: ActivityPresenter!

    // MARK: - Observation Tokens
    private var universalLinkObservationToken: NSObjectProtocol?
    private var backgroundChangeToken: NSObjectProtocol?
    private var connectionChangeToken: NSObjectProtocol?
    private var daemonFailureTokens: [NSObjectProtocol] = []

    // MARK: - State
    private var didLoadInitialSensors = false

    // MARK: - Initialization
    init(
        sensorDataService: RuuviTagDataService,
        alertService: RuuviTagAlertService,
        backgroundService: RuuviTagBackgroundService,
        connectionService: RuuviTagConnectionService,
        settingsService: DashboardSettingsService,
        cloudSyncService: DashboardCloudSyncService
    ) {
        self.sensorDataService = sensorDataService
        self.alertService = alertService
        self.backgroundService = backgroundService
        self.connectionService = connectionService
        self.settingsService = settingsService
        self.cloudSyncService = cloudSyncService

        setupServiceDelegates()
    }

    deinit {
        stopAllObservations()
    }

    // MARK: - Setup
    private func setupServiceDelegates() {
        sensorDataService.delegate = self
        alertService.delegate = self
        backgroundService.delegate = self
        connectionService.delegate = self
        settingsService.delegate = self
        cloudSyncService.delegate = self
    }

    private func startAllServices() {
        sensorDataService.startObservingSensors()
        alertService.startObservingAlerts()
        backgroundService.startObservingBackgroundChanges()
        connectionService.startObservingConnections()
        settingsService.startObservingSettings()
        cloudSyncService.startObserving()

        startObservingUniversalLinks()
        startObservingDaemonErrors()
        startObservingBackgroundChanges()
        startObservingConnectionChanges()
    }

    private func stopAllObservations() {
        sensorDataService.stopObservingSensors()
        alertService.stopObservingAlerts()
        backgroundService.stopObservingBackgroundChanges()
        connectionService.stopObservingConnections()
        settingsService.stopObservingSettings()
        cloudSyncService.stopObserving()

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
        startAllServices()
        cloudSyncService.triggerFullHistorySync()
        pushNotificationsManager.registerForRemoteNotifications()
    }

    func viewWillAppear() {
        updateViewSettings()
        settingsService.syncAppSettingsToAppGroupContainer(isAuthorized: cloudSyncService.isAuthorized())
    }

    func viewWillDisappear() {
        // Stop bluetooth state observation to avoid unnecessary alerts
        connectionService.stopObservingConnections()
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
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }

        let (isConnected, _ ) = connectionService.getConnectionStatus(
            for: snapshot
        )
        if snapshot.identifierData.luid != nil {
            if settingsService.keepConnectionDialogWasShown(for: snapshot)
                || isConnected
                || !snapshot.connectionData.isConnectable
                || !snapshot.metadata.isOwner
                || (
                    cloudSyncService.isCloudModeEnabled() && snapshot.metadata.isCloud
                ) {
                openTagSettings(for: snapshot, sensor: sensor)
            } else {
                view?.showKeepConnectionDialogSettings(for: snapshot)
            }
        } else {
            openTagSettings(for: snapshot, sensor: sensor)
        }
    }

    func viewDidTriggerChart(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }

        let (isConnected, _ ) = connectionService.getConnectionStatus(
            for: snapshot
        )
        if snapshot.identifierData.luid != nil {
            if settingsService.keepConnectionDialogWasShown(for: snapshot)
                || isConnected
                || !snapshot.connectionData.isConnectable
                || !snapshot.metadata.isOwner
                || (
                    cloudSyncService.isCloudModeEnabled() && snapshot.metadata.isCloud
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
              let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }

        openCardView(for: snapshot, sensor: sensor, showCharts: false)
    }

    func viewDidTriggerOpenSensorCardFromWidget(for snapshot: RuuviTagCardSnapshot?) {
        guard let snapshot = snapshot,
              let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }

        let showCharts = settingsService.getDashboardTapActionType() == .chart
        openCardView(for: snapshot, sensor: sensor, showCharts: showCharts)
    }

    func viewDidTriggerDashboardCard(for snapshot: RuuviTagCardSnapshot) {
        switch settingsService.getDashboardTapActionType() {
        case .card:
            viewDidTriggerOpenCardImageView(for: snapshot)
        case .chart:
            viewDidTriggerChart(for: snapshot)
        }
    }

    func viewDidTriggerChangeBackground(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        router.openBackgroundSelectionView(ruuviTag: sensor)
    }

    func viewDidTriggerRename(for snapshot: RuuviTagCardSnapshot) {
        view?.showSensorNameRenameDialog(
            for: snapshot,
            sortingType: settingsService.getCurrentDashboardSortingType()
        )
    }

    func viewDidTriggerShare(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        router.openShare(for: sensor)
    }

    func viewDidTriggerRemove(for snapshot: RuuviTagCardSnapshot) {
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        router.openRemove(for: sensor, output: self)
    }

    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        openCardView(for: snapshot, sensor: sensor, showCharts: true)
    }

    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot) {
        connectionService.setKeepConnection(true, for: snapshot)
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        openCardView(for: snapshot, sensor: sensor, showCharts: true)
    }

    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) {
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        openTagSettings(for: snapshot, sensor: sensor)
    }

    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot) {
        connectionService.setKeepConnection(true, for: snapshot)
        markKeepConnectionDialogShown(for: snapshot)
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else { return }
        openTagSettings(for: snapshot, sensor: sensor)
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
        cloudSyncService.triggerImmediateSync()
    }

    func viewDidRenameTag(to name: String, snapshot: RuuviTagCardSnapshot) {
        sensorDataService.snapshotSensorNameDidChange(to: name, for: snapshot)
    }

    func viewDidReorderSensors(with type: DashboardSortingType, orderedIds: [String]) {
        settingsService.setUserActivelyDraggingCards(true)
        if type == .alphabetical {
            settingsService.resetSensorOrder()
        } else {
            settingsService.updateSensorOrder(orderedIds)
        }

        sensorDataService.reorderSnapshots(with: orderedIds)
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

    func updateViewSettings() {
        view?.dashboardType = settingsService.getDashboardType()
        view?.dashboardTapActionType = settingsService.getDashboardTapActionType()
        view?.dashboardSortingType = settingsService.getCurrentDashboardSortingType()
    }

    func markKeepConnectionDialogShown(for snapshot: RuuviTagCardSnapshot) {
        settingsService.setKeepConnectionDialogWasShown(for: snapshot)
    }

    func openTagSettings(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor) {
        let sensorSettings = sensorDataService.getSensorSettings()
        let relevantSetting = sensorSettings.first { setting in
            (setting.luid?.any != nil && setting.luid?.any == snapshot.identifierData.luid?.any) ||
            (setting.macId?.any != nil && setting.macId?.any == snapshot.identifierData.mac?.any)
        }

        router.openTagSettings(
            ruuviTag: sensor,
            latestMeasurement: snapshot.latestRawRecord,
            sensorSettings: relevantSetting,
            output: self
        )
    }

    func openCardView(for snapshot: RuuviTagCardSnapshot, sensor: AnyRuuviTagSensor, showCharts: Bool) {
        let allSnapshots = sensorDataService.getAllSnapshots()
        let allSensors = sensorDataService.getAllSensors()
        let sensorSettings = sensorDataService.getSensorSettings()

        // Create CardsViewModel for backward compatibility with router
        let viewModel = createViewModelFromSnapshot(snapshot)
        let allViewModels = allSnapshots.compactMap { createViewModelFromSnapshot($0) }

        router.openCardImageView(
            with: allViewModels,
            ruuviTagSensors: allSensors,
            sensorSettings: sensorSettings,
            scrollTo: viewModel,
            showCharts: showCharts,
            output: self
        )
    }

    func createViewModelFromSnapshot(_ snapshot: RuuviTagCardSnapshot) -> LegacyCardsViewModel {
        // Create a temporary CardsViewModel for backward compatibility
        // This should be removed once router is updated to use snapshots
        guard let sensor = sensorDataService.getSensor(for: snapshot.id) else {
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
                if let email = self?.cloudSyncService.getUserEmail() {
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

    func startObservingBackgroundChanges() {
        backgroundChangeToken = NotificationCenter.default.addObserver(
            forName: .DashboardBackgroundDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let sensorId = userInfo["sensorId"] as? String,
                  let snapshot = self.sensorDataService.getSnapshot(for: sensorId),
                  let sensor = self.sensorDataService.getSensor(for: sensorId) else { return }

            self.backgroundService.loadBackground(for: snapshot, sensor: sensor)
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
            let snapshots = self.sensorDataService.getAllSnapshots()
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
              !cloudSyncService.isAuthorized() else { return }

        router.openSignIn(output: self)
    }
}

// MARK: - Service Delegates
extension DashboardPresenter: RuuviTagDataServiceDelegate {

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    ) {
        view?.updateSnapshots(snapshots, withAnimation: withAnimation)
        view?.showNoSensorsAddedMessage(show: snapshots.isEmpty)

        if didLoadInitialSensors {
            settingsService.askAppStoreReview(with: snapshots.count)
        }
        didLoadInitialSensors = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Update connection data
            self.connectionService.updateConnectionData(for: snapshots)

            // Subscribe to alerts
            self.alertService.subscribeToAlerts(for: snapshots)

            // Load backgrounds
            let sensors = self.sensorDataService.getAllSensors()
            self.backgroundService.loadBackgrounds(for: snapshots, sensors: sensors)

            // Update sign in banner and cloud sensor info on main thread
            DispatchQueue.main.async {
                self.updateSignInBannerVisibility(sensorCount: snapshots.count)

                let hasCloudSensors = snapshots.contains { $0.metadata.isCloud }
                self.settingsService.syncHasCloudSensorToAppGroupContainer(hasCloudSensors: hasCloudSensors)
            }
        }
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    ) {
        view?.updateSnapshot(from: snapshot, invalidateLayout: invalidateLayout)
        alertService.triggerAlertsIfNeeded(for: snapshot)
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didAddNewSensor sensor: RuuviTagSensor,
        newOrder: [String]
    ) {
        checkFirmwareVersion(for: sensor)
        if !newOrder.isEmpty {
            viewDidReorderSensors(with: .manual, orderedIds: newOrder)
        }
        if let snapshot = sensorDataService.getSnapshot(for: sensor.id) {
            viewDidTriggerSettings(for: snapshot)
        }
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didEncounterError error: Error
    ) {
        errorPresenter.present(error: error)
    }
}

extension DashboardPresenter: RuuviTagAlertServiceDelegate {

    func alertService(
        _ service: RuuviTagAlertService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        view?
            .updateSnapshot(
                from: snapshot
            )
    }

    func alertService(
        _ service: RuuviTagAlertService,
        alertsDidChange: Bool
    ) {
        if alertsDidChange {
            // Trigger alerts if needed
            let snapshots = sensorDataService.getAllSnapshots()
            service
                .triggerAlertsIfNeeded(
                    for: snapshots
                )
        }
    }

    func getCurrentSnapshot(for sensorId: String) -> RuuviTagCardSnapshot? {
        return sensorDataService.getSnapshot(for: sensorId)
    }
}

extension DashboardPresenter: RuuviTagBackgroundServiceDelegate {

    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        view?
            .updateSnapshot(
                from: snapshot
            )
    }

    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didEncounterError error: Error
    ) {
        errorPresenter
            .present(
                error: error
            )
    }
}

extension DashboardPresenter: RuuviTagConnectionServiceDelegate {

    func connectionService(
        _ service: RuuviTagConnectionService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        view?
            .updateSnapshot(
                from: snapshot
            )
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        bluetoothStateChanged isEnabled: Bool,
        userDeclined: Bool
    ) {
        let snapshots = sensorDataService.getAllSnapshots()
        if service
            .hasBluetoothSensors(
                in: snapshots
            ) && (
                !isEnabled || userDeclined
            ) {
            view?
                .showBluetoothDisabled(
                    userDeclined: userDeclined
                )
        }
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        didEncounterError error: Error
    ) {
        errorPresenter
            .present(
                error: error
            )
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
        sensorDataService
            .reorderSnapshots(
                with: orderedIds
            )
    }

    func settingsService(
        _ service: DashboardSettingsService,
        measurementUnitsDidChange: Bool
    ) {
        // Trigger view reload for unit changes
        let snapshots = sensorDataService.getAllSnapshots()
        view?.updateSnapshots(snapshots, withAnimation: false)
    }

    func settingsService(
        _ service: DashboardSettingsService,
        calibrationSettingsDidChange: Bool
    ) {
        // Restart observing sensor records to apply new calibration
        sensorDataService
            .stopObservingSensors()
        sensorDataService
            .startObservingSensors()
    }

    func settingsService(
        _ service: DashboardSettingsService,
        languageDidChange: Bool
    ) {
        // Trigger view reload for language changes
        let snapshots = sensorDataService.getAllSnapshots()
        view?.updateSnapshots(snapshots, withAnimation: false)
    }
}

extension DashboardPresenter: DashboardCloudSyncServiceDelegate {

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        userDidLogin loggedIn: Bool
    ) {
        // No op.
    }

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        userDidLogOut loggedOut: Bool
    ) {
        sensorDataService.startObservingSensors()
    }

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        syncStatusDidChange isRefreshing: Bool
    ) {
        view?.isRefreshing = isRefreshing
    }

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        syncDidComplete: Bool
    ) {
        if syncDidComplete {
            let snapshots = sensorDataService.getAllSnapshots()
            alertService
                .triggerAlertsIfNeeded(
                    for: snapshots
                )
        }
    }

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        authorizationFailed: Bool
    ) {
        if authorizationFailed {
            // Handle forced logout
            sensorDataService
                .stopObservingSensors()
            sensorDataService
                .startObservingSensors()

            updateSignInBannerVisibility(
                sensorCount: sensorDataService.getAllSnapshots().count
            )
        }
    }

    func cloudSyncService(
        _ service: DashboardCloudSyncService,
        cloudModeDidChange isEnabled: Bool
    ) {
        // Remove connections for cloud tags when cloud mode changes
        let snapshots = sensorDataService.getAllSnapshots()
        connectionService
            .removeConnectionsForCloudSensors(
                snapshots: snapshots
            )

        // Restart sensor observations
        sensorDataService
            .stopObservingSensors()
        sensorDataService
            .startObservingSensors()

        // Update app group settings
        settingsService
            .syncAppSettingsToAppGroupContainer(
                isAuthorized: cloudSyncService.isAuthorized()
            )
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
        cloudSyncService.triggerFullHistorySync()
        sensorDataService.stopObservingSensors()
        sensorDataService.startObservingSensors()
        cloudSyncService.startObserving()

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

        if let snapshot = sensorDataService.getSnapshot(for: ruuviTag.id) {
            openCardView(for: snapshot, sensor: ruuviTag.any, showCharts: false)
        }
    }
}

extension DashboardPresenter: DashboardRouterDelegate {

    func shouldDismissDiscover() -> Bool {
        return !sensorDataService.getAllSnapshots().isEmpty
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
            self?.sensorDataService.stopObservingSensors()
            self?.sensorDataService.startObservingSensors()
        }
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

extension DashboardPresenter: SensorRemovalModuleOutput {

    func sensorRemovalDidRemoveTag(module: SensorRemovalModuleInput, ruuviTag: RuuviTagSensor) {
        module.dismiss { [weak self] in
            self?.sensorDataService.stopObservingSensors()
            self?.sensorDataService.startObservingSensors()
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
            isAuthorized: cloudSyncService.isAuthorized(),
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
