// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviLocal
import RuuviPresenters
import RuuviPersistence
import BTKit
import CoreBluetooth

class CardsBasePresenter: NSObject {

    weak var view: CardsBaseViewInput?
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
        let centralAuthorization = CBManager.authorization
        if centralAuthorization == .denied || centralAuthorization == .restricted {
            return false
        }

        let peripheralStatus = CBPeripheralManager.authorizationStatus()
        switch peripheralStatus {
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

    // MARK: Observations
    private var sensorOrderChangeToken: NSObjectProtocol?
    private var stateToken: ObservationToken?

    init(
        measurementPresenter: CardsMeasurementPresenter,
        graphPresenter: CardsGraphPresenter,
        alertsPresenter: CardsAlertsPresenter,
        settingsPresenter: CardsSettingsPresenter,
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

    // TODO: Move this to service coordinator
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
extension CardsBasePresenter: CardsBasePresenterInput {

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

// MARK: CardsBaseViewOutput
extension CardsBasePresenter: CardsBaseViewOutput {
    func appWillMoveToForeground() {
        if activeMenu == .graph {
            // If graph is active, we need to reconfigure the graph presenter
            // to ensure it has the latest data.
            graphPresenter?.reloadChartsData(
                shouldSyncFromCloud: true
            )
        }
    }

    func viewWillAppear() {
        view?.setActiveTab(activeMenu)
        view?.setSnapshots(snapshots)
        view?.setActiveSnapshotIndex(currentSnapshotIndex())

        measurementPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )

        graphPresenter?
            .configure(
                with: snapshots,
                snapshot: snapshot,
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )
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

    func viewDidScrollToGraph(for measurement: MeasurementType) {
        graphPresenter?.start(shouldSyncFromCloud: false)
        graphPresenter?.scroll(to: measurement)
        view?.showContentsForTab(.graph)
        activeMenu = .graph
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
            measurementPresenter?.scroll(to: currentSnapshotIndex(), animated: false)
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
            settings.setKeepConnectionDialogWasShown(true, for: luid)
            graphPresenter?.start(shouldSyncFromCloud: true)
            view?.showContentsForTab(.graph)
            activeMenu = .graph
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            settings.setKeepConnectionDialogWasShown(true, for: luid)
            graphPresenter?.start(shouldSyncFromCloud: true)
            view?.showContentsForTab(.graph)
            activeMenu = .graph
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidConfirmToKeepConnectionSettings(to snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            connectionPersistence.setKeepConnection(true, for: luid)
            settings.setKeepConnectionDialogWasShown(true, for: luid)
            showTagSettings(for: snapshot)
        } else {
            errorPresenter.present(error: UnexpectedError.viewModelUUIDIsNil)
        }
    }

    func viewDidDismissKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) {
        if let luid = snapshot.identifierData.luid {
            settings.setKeepConnectionDialogWasShown(true, for: luid)
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
        settings.setFirmwareUpdateDialogWasShown(true, for: luid)
    }
}

// MARK: CardsMeasurementPresenterOutput
extension CardsBasePresenter: CardsMeasurementPresenterOutput {
    func measurementPresenter(
        _ presenter: CardsMeasurementPresenter,
        didNavigateToIndex index: Int
    ) {
        switch activeMenu {
        case .measurement:
            viewShouldNavigateToSnapshotIndex(index)
        default:
            break
        }
    }

    func showMeasurementDetails(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        settings: SensorSettings?,
        presenter: CardsMeasurementPresenter
    ) {
        view?.showMeasurementDetails(
            for: indicator,
            snapshot: snapshot,
            sensor: sensor,
            settings: settings
        )
    }
}

// MARK: CardsGraphPresenterOutput
extension CardsBasePresenter: CardsGraphPresenterOutput {
    func setGraphGattSyncInProgress(_ inProgress: Bool) {
        graphGattSyncInProgress = inProgress
    }

    func graphGattSyncAborted(
        for snapshot: RuuviTagCardSnapshot,
        source: GraphHistoryAbortSyncSource
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
extension CardsBasePresenter: TagSettingsModuleOutput {
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
extension CardsBasePresenter: RuuviTagServiceCoordinatorObserver {

    // swiftlint:disable:next function_body_length
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        switch event {
        case .snapshotsUpdated(let snapshots, let reason, _):
            if snapshots.count > 0 {
                // If new snapshots collection does not contain the active snapshot
                // that means active snapshot is removed from collection either by
                // user from this client or via sync.
                // In that case update the active snapshot with first item
                // from the collection.
#if DEBUG || ALPHA
                print("Snapshots updated with reason: \(reason)")
#endif
                switch reason {
                case .delete(let deleted):
                    // If current snapshot was deleted, select first
                    if deleted.first(where: {
                           $0.id == self.snapshot.id &&
                           $0.identifierData.luid?.value == self.snapshot.identifierData.luid?.value &&
                           $0.identifierData.mac?.value == self.snapshot.identifierData.mac?.value }) != nil {
                        self.snapshots = snapshots
                        self.snapshot = snapshots.first
                    } else {
                        // Current snapshot still exists, just update array
                        self.snapshots = snapshots
                    }
                case .initial, .reorder, .insert, .update, .mixed:
                    // For all other cases, keep current snapshot if it still exists
                    if snapshots.first(where: {
                        $0.id == self.snapshot.id &&
                        $0.identifierData.luid?.any == self.snapshot.identifierData.luid?.any &&
                        $0.identifierData.mac?.any == self.snapshot.identifierData.mac?.any }) != nil {
                        self.snapshots = snapshots
                    } else {
                        self.snapshots = snapshots
                        self.snapshot = snapshots.first
                    }
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
                        sensor: currentSensor(),
                        settings: currentSensorSettings()
                    )

                graphPresenter?
                    .configure(
                        with: snapshots,
                        snapshot: snapshot,
                        sensor: currentSensor(),
                        settings: currentSensorSettings()
                    )

                switch reason {
                case .reorder, .delete:
                    // If snapshots were reordered or deleted, we need to rebuild the presenters
                    measurementPresenter?.start()
                    measurementPresenter?
                        .scroll(to: currentSnapshotIndex(), animated: false)
                    graphPresenter?.start(shouldSyncFromCloud: true)
                default:
                    break
                }
            } else {
                viewDidTapBackButton()
            }
        default:
            break
        }
    }
}

// MARK: RuuviCloudServiceDelegate
extension CardsBasePresenter: RuuviCloudServiceDelegate {
    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogin loggedIn: Bool
    ) {
        // no op.
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogOut loggedOut: Bool
    ) {
        // no op.
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
        // no op.
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
        // no op.
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        cloudModeDidChange isEnabled: Bool
    ) {
        // no op.
    }
}

// MARK: Private Helpers
private extension CardsBasePresenter {
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
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )
        graphPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )
        alertsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )
        settingsPresenter?
            .configure(
                with: snapshot,
                sensor: currentSensor(),
                settings: currentSensorSettings()
            )
    }

    func startObservingBluetoothState() {
        stateToken = foreground.state(self, closure: { [weak self] _, state in
            self?.handleBluetoothStateChange(state)
        })
        handleBluetoothStateChange(foreground.bluetoothState)
    }

    func stopObservingBluetoothState() {
        stateToken?.invalidate()
    }

    func handleBluetoothStateChange(_ state: BTScannerState) {
        let permissionDenied = !isBluetoothPermissionGranted
        if permissionDenied {
            view?.showBluetoothDisabled(userDeclined: true)
            return
        }

        switch state {
        case .poweredOff,
             .unsupported:
            view?.showBluetoothDisabled(userDeclined: false)
        case .unauthorized:
            view?.showBluetoothDisabled(userDeclined: true)
        default:
            break
        }
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
            let firmwareType      = RuuviDataFormat.dataFormat(
                from: snapshot.displayData.version.bound
            )
            let isAir             = firmwareType == .e1 || firmwareType == .v6

            if skipDialogShown
                || isConnected
                || isNotConnectable
                || isNotOwner
                || cloudModeBypass
                || isAir {
                graphPresenter?.start(shouldSyncFromCloud: true)
                view?.showContentsForTab(tab)
                activeMenu = tab
            } else {
                view?.showKeepConnectionDialogChart(for: snapshot)
            }
        } else if snapshot.identifierData.mac != nil {
            graphPresenter?.start(shouldSyncFromCloud: true)
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
            let firmwareType      = RuuviDataFormat.dataFormat(
                from: snapshot.displayData.version.bound
            )
            let isAir             = firmwareType == .e1 || firmwareType == .v6

            if skipDialogShown
                || isConnected
                || isNotConnectable
                || isNotOwner
                || cloudModeBypass
                || isAir {
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
                $0.luid?.any == sensor.luid?.any ||
                $0.macId?.any == sensor.macId?.any
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
        return snapshots.firstIndex(where: {
            $0.id == snapshot.id &&
            $0.identifierData.luid?.any == snapshot.identifierData.luid?.any &&
            $0.identifierData.mac?.any == snapshot.identifierData.mac?.any
        }) ?? 0
    }

    func currentSensorSettings() -> SensorSettings? {
        return sensorSettings.first(where: {
            $0.luid?.any == snapshot.identifierData.luid?.any ||
            $0.macId?.any == snapshot.identifierData.mac?.any
        })
    }
}

// swiftlint:enable file_length
