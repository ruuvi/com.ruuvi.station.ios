import Foundation
import RuuviOntology
import RuuviLocal
import RuuviPresenters
import RuuviPersistence
import BTKit
import CoreBluetooth

class NewCardsBasePresenter: NSObject {

    weak var view: NewCardsBaseViewInput?
    var router: CardsRouterInput?

    // MARK: Child presenter references
    private weak var measurementPresenter: CardsMeasurementPresenterInput?
    private weak var graphPresenter: CardsGraphPresenterInput?
    private weak var alertsPresenter: CardsAlertsPresenterInput?
    private weak var settingsPresenter: CardsSettingsPresenterInput?

    // MARK: Module Output
    weak private var output: CardsBasePresenterOutput?

    // MARK: Dependencies
    private let foreground: BTForeground
    private let ruuviCloudService: RuuviCloudService
    private let settings: RuuviLocalSettings
    private let connectionPersistence: RuuviLocalConnections
    private let errorPresenter: ErrorPresenter
    private let featureToggleService: FeatureToggleService

    // MARK: Properties
    private var snapshot: RuuviTagCardSnapshot!
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var ruuviTagSensors: [AnyRuuviTagSensor] = []
    private var sensorSettings: [SensorSettings] = []
    private var activeMenu: CardsMenuType = .measurement

    private var graphGattSyncInProgress: Bool = false

    private var isBluetoothPermissionGranted: Bool {
        CBCentralManager.authorization == .allowedAlways
    }

    private var sensorOrderChangeToken: NSObjectProtocol?

    // MARK: Observations
    private var stateToken: ObservationToken?

    init(
        measurementPresenter: NewCardsMeasurementPresenter,
        graphPresenter: NewCardsGraphPresenter,
        alertsPresenter: NewCardsAlertsPresenter,
        settingsPresenter: NewCardsSettingsPresenter,
        foreground: BTForeground,
        ruuviCloudService: RuuviCloudService,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections,
        errorPresenter: ErrorPresenter,
        featureToggleService: FeatureToggleService
    ) {
        self.measurementPresenter = measurementPresenter
        self.graphPresenter = graphPresenter
        self.alertsPresenter = alertsPresenter
        self.settingsPresenter = settingsPresenter

        self.foreground = foreground
        self.ruuviCloudService = ruuviCloudService
        self.settings = settings
        self.connectionPersistence = connectionPersistence
        self.errorPresenter = errorPresenter
        self.featureToggleService = featureToggleService
        super.init()

        self.startObservingSensorOrderChanges()
        self.startServices()
        self.startObservingBluetoothState()
        self.measurementPresenter?.configure(output: self)
        self.graphPresenter?.configure(output: self)
    }

    // TODO: Move this to coordinator
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
                        RuuviTagServiceCoordinatorManager.shared
                            .reorderSnapshots(with: self.settings.dashboardSensorOrder)
                    }
                }
            )
    }
}

// MARK: CardsBasePresenterInput
extension NewCardsBasePresenter: CardsBasePresenterInput {

    // swiftlint:disable:next function_parameter_count
    func configure(
        for snapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        output: CardsBasePresenterOutput?
    ) {
        self.snapshot = snapshot
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.sensorSettings = sensorSettings
        self.activeMenu = activeMenu
        self.output = output

        // Configure all presenter with active snapshot and associated sensor
        syncPresenters()
    }

    func dismiss(completion: (() -> Void)?) {
        // TODO: Cleanup
        stopServices()
        stopObservingBluetoothState()
        // Call Completetion
        completion?()
    }
}

// MARK: NewCardsBaseViewOutput
extension NewCardsBasePresenter: NewCardsBaseViewOutput {
    func viewWillAppear() {
        view?.setActiveTab(activeMenu)
        view?.setSnapshots(snapshots)
        view?.setActiveSnapshotIndex(currentSnapshotIndex())

        measurementPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor()
            )

        graphPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor()
            )
        graphPresenter?.configure(sensorSettings: currentSensorSettings())
    }

    func viewDidChangeTab(_ tab: CardsMenuType) {
        switch tab {
        case .measurement:
            viewDidRequestToShowMeasurement(for: snapshot, tab: tab)
        case .graph:
            viewDidRequestToShowGraph(for: snapshot, tab: tab)
        case .alerts, .settings:
            viewDidRequestToShowSettings(for: snapshot, tab: tab)
        }
    }

    func viewDidRequestNavigateToSnapshotIndex(_ index: Int) {
        switch activeMenu {
        case .graph:
            if graphGattSyncInProgress {
                graphPresenter?
                    .showAbortSyncConfirmationDialog(
                        for: snapshot,
                        from: .rootNavigationButton(index)
                    )
            } else {
                viewShouldNavigateToSnapshotIndex(index)
            }
        // For other tabs than graph we do not have a precondition yet.
        // So, navigate immediately.
        default:
            viewShouldNavigateToSnapshotIndex(index)
        }
    }

    func viewShouldNavigateToSnapshotIndex(_ index: Int) {
        guard index >= 0 && index < snapshots.count &&
                index != currentSnapshotIndex() else {
            return
        }

        snapshot = snapshots[index]

        // Configure all presenter with active snapshot and associated sensor
        syncPresenters()
        triggerFirmwareUpdateDialogIfNeeded(for: snapshot)

        // Update main view
        view?.setActiveSnapshotIndex(index)

        // Update active menu page
        switch activeMenu {
        case .measurement:
            measurementPresenter?.scroll(to: currentSnapshotIndex(), animated: true)
        case .graph:
            graphPresenter?.scroll(to: currentSnapshotIndex(), animated: true)
        case .alerts, .settings:
            break // TODO: Implement
        }
    }

    func viewDidTapBackButton() {
        if graphGattSyncInProgress {
            graphPresenter?
                .showAbortSyncConfirmationDialog(
                    for: snapshot,
                    from: .rootBackButton
                )
        } else {
            output?.cardsViewDidDismiss(module: self)
        }
    }

    func viewDidConfirmToKeepConnectionChart(to snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            graphPresenter?.start()
            view?.showContentsForTab(.graph)
            activeMenu = .graph
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            graphPresenter?.start()
            view?.showContentsForTab(.graph)
            activeMenu = .graph
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(for: luid)
            showTagSettings(for: snapshot)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            settings.setKeepConnectionDialogWasShown(for: luid)
            showTagSettings(for: snapshot)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmFirmwareUpdate(for snapshot: RuuviTagCardSnapshot) {
        if let sensor = ruuviTagSensors
            .first(where: {
                $0.luid != nil && ($0.luid?.any == snapshot.identifierData.luid?.any)
            }) {
            router?.openUpdateFirmware(ruuviTag: sensor)
        }
    }

    /// Trigger this method when user cancel the legacy firmware update dialog for the first time
    func viewDidIgnoreFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) {
        view?.showFirmwareDismissConfirmationUpdateDialog(for: snapshot)
    }

    /// Trigger this method when user confirms the lagacy firmware update dialog dismiss for the second time
    func viewDidDismissFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) {
        guard let luid = snapshot.identifierData.luid else { return }
        settings.setFirmwareUpdateDialogWasShown(for: luid)
    }
}

// MARK: CardsMeasurementPresenterOutput
extension NewCardsBasePresenter: CardsMeasurementPresenterOutput {
    func measurementPresenter(
        _ presenter: NewCardsMeasurementPresenter,
        didNavigateToIndex index: Int
    ) {
        switch activeMenu {
        case .measurement:
            viewShouldNavigateToSnapshotIndex(index)
        default:
            break
        }
    }
}

// MARK: CardsGraphPresenterOutput
extension NewCardsBasePresenter: CardsGraphPresenterOutput {
    func setGraphGattSyncInProgress(_ inProgress: Bool) {
        graphGattSyncInProgress = inProgress
    }

    func graphGattSyncAborted(
        for snapshot: RuuviTagCardSnapshot,
        source: AbortSyncSource
    ) {
        switch source {
        case .rootBackButton:
            // Go back to root
            graphPresenter?.stop()
            viewDidTapBackButton()
        case .rootNavigationButton(let targetIndex):
            // Navigate to next/previous
            viewShouldNavigateToSnapshotIndex(targetIndex)
        case .topMenuSwitch:
            // Update presenter
            activeMenu = .measurement
            // Update view
            view?.showContentsForTab(activeMenu)
            // Stop graph
            graphPresenter?.stop()
        case .inPageCancel:
            // Do nothing as it is handled on the graph presenter.
            break
        }
    }
}

// MARK: TagSettingsModuleOutput
extension NewCardsBasePresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: {
            // No need to anything on completion.
            // View should get updated state from Data Service.
        })
    }

    func tagSettingsDidDismiss(module: any TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}

// MARK: RuuviTagServiceCoordinatorObserver
extension NewCardsBasePresenter: RuuviTagServiceCoordinatorObserver {
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        switch event {
        case .snapshotsUpdated(let snapshots, _):
            if snapshots.count > 0 {
                // If new snapshots collection does not contain the active snapshot
                // that means active snapshot is removed from collection either by
                // user from this client or via sync.
                // In that case update the active snapshot with first item
                // from the collection.
                if snapshots.count < self.snapshots.count,
                   !snapshots.contains(self.snapshot) {
                    self.snapshots = snapshots
                    snapshot = snapshots.first
                }

                // Order is very important for next calls.
                self.ruuviTagSensors = coordinator.getAllSensors()
                self.sensorSettings = coordinator.getSensorSettings()

                view?.setSnapshots(snapshots)
                view?.setActiveSnapshotIndex(currentSnapshotIndex())

                measurementPresenter?
                    .configure(
                        with: snapshots,
                        snapshot: snapshot,
                        sensor: currentSensor()
                    )

                graphPresenter?
                    .configure(
                        with: snapshots,
                        snapshot: snapshot,
                        sensor: currentSensor()
                    )
                graphPresenter?.configure(sensorSettings: currentSensorSettings())
            } else {
                viewDidTapBackButton()
            }
        default:
            break
//        case .snapshotUpdated(let ruuviTagCardSnapshot, let invalidateLayout):
//            <#code#>
//        case .newSensorAdded(let ruuviTagSensor, let newOrder):
//            <#code#>
//        case .dataServiceError(let error):
//            <#code#>
//        case .backgroundUpdated(let sensorId, let luid, let macId):
//            <#code#>
//        case .userLoginStateChanged(let bool):
//            <#code#>
//        case .userLogoutStateChanged(let bool):
//            <#code#>
//        case .cloudSyncStatusChanged(let bool):
//            <#code#>
//        case .cloudSyncCompleted:
//            <#code#>
//        case .historySyncInProgress(let bool, let macId):
//            <#code#>
//        case .authorizationFailed:
//            <#code#>
//        case .cloudModeChanged(let bool):
//            <#code#>
//        case .alertSnapshotUpdated(let ruuviTagCardSnapshot):
//            <#code#>
//        case .alertsChanged:
//            <#code#>
//        case .connectionSnapshotUpdated(let ruuviTagCardSnapshot):
//            <#code#>
//        case .bluetoothStateChanged(let isEnabled, let userDeclined):
//            <#code#>
//        case .connectionServiceError(let error):
//            <#code#>
        }
    }
}

// MARK: RuuviCloudServiceDelegate
extension NewCardsBasePresenter: RuuviCloudServiceDelegate {
    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogin loggedIn: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogOut loggedOut: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncStatusDidChange isRefreshing: Bool
    ) {
        view?.setActivityIndicatorVisible(isRefreshing)
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncDidComplete: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        historySyncInProgress inProgress: Bool,
        for macId: String
    ) {
        if activeMenu == .graph,
            snapshot.identifierData.mac?.value == macId {
            view?.setActivityIndicatorVisible(inProgress)
        }
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        authorizationFailed: Bool
    ) {
        //
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        cloudModeDidChange isEnabled: Bool
    ) {
        //
    }
}

// MARK: Private Helpers
private extension NewCardsBasePresenter {
    func startServices() {
        RuuviTagServiceCoordinatorManager.shared.addObserver(self)
        ruuviCloudService.startObserving()

        ruuviCloudService.delegate = self
    }

    func stopServices() {
        RuuviTagServiceCoordinatorManager.shared.removeObserver(self)
        ruuviCloudService.stopObserving()
    }

    func syncPresenters() {
        measurementPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        graphPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        alertsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
        settingsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor()
            )
    }

    func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { [weak self] observer, state in
            guard let sSelf = self else { return }
            if state != .poweredOn || !sSelf.isBluetoothPermissionGranted {
                observer.view?.showBluetoothDisabled(userDeclined: !sSelf.isBluetoothPermissionGranted)
            }
        })
    }

    func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    func viewDidRequestToShowGraph(
        for snapshot: RuuviTagCardSnapshot,
        tab: CardsMenuType
    ) {
        if let luid = snapshot.identifierData.luid {
            let skipDialogShown   = settings.keepConnectionDialogWasShown(for: luid)
            let isConnected       = snapshot.connectionData.isConnected
            let isNotConnectable  = !snapshot.connectionData.isConnectable
            let isNotOwner        = !snapshot.metadata.isOwner
            let cloudModeBypass   = settings.cloudModeEnabled && snapshot.metadata.isCloud

            if skipDialogShown
                || isConnected
                || isNotConnectable
                || isNotOwner
                || cloudModeBypass {
                graphPresenter?.start()
                view?.showContentsForTab(tab)
                activeMenu = tab
            } else {
                view?.showKeepConnectionDialogChart(for: snapshot)
            }
        } else if snapshot.identifierData.mac != nil {
            graphPresenter?.start()
            view?.showContentsForTab(tab)
            activeMenu = tab
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidRequestToShowMeasurement(
        for snapshot: RuuviTagCardSnapshot,
        tab: CardsMenuType
    ) {
        if graphGattSyncInProgress {
            graphPresenter?
                .showAbortSyncConfirmationDialog(
                    for: snapshot,
                    from: .topMenuSwitch
                )
        } else {
            // Update presenter
            activeMenu = tab
            // Update view
            view?.showContentsForTab(tab)
            // Stop graph
            graphPresenter?.stop()
        }
    }

    func viewDidRequestToShowSettings(
        for snapshot: RuuviTagCardSnapshot,
        tab: CardsMenuType
    ) {
        if let luid = snapshot.identifierData.luid {
            let skipDialogShown   = settings.keepConnectionDialogWasShown(for: luid)
            let isConnected       = snapshot.connectionData.isConnected
            let isNotConnectable  = !snapshot.connectionData.isConnectable
            let isNotOwner        = !snapshot.metadata.isOwner
            let cloudModeBypass   = settings.cloudModeEnabled && snapshot.metadata.isCloud

            if skipDialogShown
                || isConnected
                || isNotConnectable
                || isNotOwner
                || cloudModeBypass {
                showTagSettings(for: snapshot)
            } else {
                view?.showKeepConnectionDialogSettings(for: snapshot)
            }
        } else if snapshot.identifierData.mac != nil {
            showTagSettings(for: snapshot)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func showTagSettings(for snapshot: RuuviTagCardSnapshot) {
        if let sensor = ruuviTagSensors.first(where: {
            $0.id == snapshot.id
        }) {
            let settings = sensorSettings.first(where: {
                $0.luid?.value == sensor.luid?.value ||
                $0.macId?.value == sensor.macId?.value
            })
            router?.openTagSettings(
                ruuviTag: sensor,
                latestMeasurement: snapshot.latestRawRecord,
                sensorSettings: settings,
                output: self
            )
        }
    }

    func triggerFirmwareUpdateDialogIfNeeded(for snapshot: RuuviTagCardSnapshot) {
        guard let luid = snapshot.identifierData.luid,
              let version = snapshot.displayData.version, version < 5,
              snapshot.metadata.isOwner,
              featureToggleService.isEnabled(.legacyFirmwareUpdatePopup)
        else {
            return
        }
        if !settings.firmwareUpdateDialogWasShown(for: luid) {
            view?.showFirmwareUpdateDialog(for: snapshot)
        }
    }

    func currentSensor() -> AnyRuuviTagSensor? {
        return ruuviTagSensors.first(where: {
            $0.id == snapshot.id
        })
    }

    func currentSnapshotIndex() -> Int {
        return snapshots.firstIndex(of: snapshot) ?? 0
    }

    func currentSensorSettings() -> SensorSettings? {
        return sensorSettings.first(where: {
            $0.luid?.value == snapshot.identifierData.luid?.value ||
            $0.macId?.value == snapshot.identifierData.mac?.value
        })
    }
}
