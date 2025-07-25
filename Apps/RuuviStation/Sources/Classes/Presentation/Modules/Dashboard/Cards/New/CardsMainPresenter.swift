import Foundation
import RuuviOntology
import RuuviService
import RuuviLocal
import UIKit
import RuuviPresenters
import BTKit
import Swinject

// MARK: - Main Presenter
final class CardsMainPresenter: CardsLandingViewOutput {

    // MARK: - Properties
    weak var view: CardsLandingViewInput?
    weak var output: NewCardsModuleOutput?

    private var router: CardsRouterInput

    // MARK: - Tab Controllers
    private var tabControllers: [CardsMenuType: UIViewController] = [:]

    // MARK: - Tab Presenters
    private var measurementPresenter: CardsMeasurementPresenter?
    private var graphPresenter: CardsGraphPresenter?
    private var alertsPresenter: CardsAlertsPresenter?
    private var settingsPresenter: CardsSettingsPresenter?

    // MARK: - State
    private var currentTab: CardsMenuType = .measurement
    private var currentSnapshotIndex: Int = 0
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var ruuviTagSensors: [AnyRuuviTagSensor] = []

    // MARK: - Configuration State
    private var hasInitialConfiguration = false
    private var initialActiveMenu: CardsMenuType = .measurement
    private var isApplyingInitialConfiguration = false

    // MARK: - Services
    private let dataService: RuuviTagDataService
    private let alertService: RuuviTagAlertService
    private let backgroundService: RuuviTagBackgroundService
    private let connectionService: RuuviTagConnectionService
    private let dashboardCloudSyncService: RuuviCloudService
    private let settings: RuuviLocalSettings
    private let flags: RuuviLocalFlags

    // MARK: - Safe Update Coordination
    private let updateQueue = DispatchQueue(label: "com.ruuvi.cardsUpdate", qos: .utility)
    private var pendingUpdates: [String: RuuviTagCardSnapshot] = [:]
    private var updateWorkItem: DispatchWorkItem?

    // MARK: - Initialization
    init(
        dataService: RuuviTagDataService,
        alertService: RuuviTagAlertService,
        backgroundService: RuuviTagBackgroundService,
        connectionService: RuuviTagConnectionService,
        dashboardCloudSyncService: RuuviCloudService,
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags,
        router: CardsRouterInput
    ) {
        self.dataService = dataService
        self.alertService = alertService
        self.backgroundService = backgroundService
        self.connectionService = connectionService
        self.dashboardCloudSyncService = dashboardCloudSyncService
        self.settings = settings
        self.flags = flags
        self.router = router

        setupServiceDelegates()
    }

    deinit {
        stopServices()
        updateWorkItem?.cancel()
    }

    // MARK: - Public Methods
    func setupTabControllers(_ controllers: [CardsMenuType: UIViewController]) {
        tabControllers = controllers
        createTabPresenters()
    }

    func getCurrentSnapshot() -> RuuviTagCardSnapshot? {
        guard currentSnapshotIndex >= 0 && currentSnapshotIndex < snapshots.count else { return nil }
        return snapshots[currentSnapshotIndex]
    }

    func getCurrentSensor() -> AnyRuuviTagSensor? {
        if let currentSnapshot = getCurrentSnapshot() {
            return ruuviTagSensors.first(where: {
                $0.id == currentSnapshot.id
            })
        }
        return nil
    }

    // MARK: - Service Management
    private func startServices() {
        dataService.startObservingSensors()

        do {
            alertService.startObservingAlerts()
        } catch {
            print("Failed to start alert service: \(error)")
        }

        backgroundService.startObservingBackgroundChanges()
        connectionService.startObservingConnections()
        dashboardCloudSyncService.startObserving()
    }

    private func stopServices() {
        dataService.stopObservingSensors()
        alertService.stopObservingAlerts()
        backgroundService.stopObservingBackgroundChanges()
        connectionService.stopObservingConnections()
        dashboardCloudSyncService.stopObserving()
    }

    // MARK: - CardsLandingViewOutput
    func viewDidLoad() {
        if hasInitialConfiguration {
            applyInitialConfiguration()
            startServices()
        } else {
            startServices()
            loadInitialData()
        }
    }

    func viewWillAppear() {
        if !hasInitialConfiguration {
            startServices()
            refreshCurrentData()
        }
    }

    func viewWillDisappear() {
        updateWorkItem?.cancel()
    }

    func viewDidChangeTab(_ tab: CardsMenuType) {
        if flags.showRedesignedCardsUIWithoutNewMenu {
            switch tab {
            case .measurement, .graph:
                currentTab = tab
                view?.updateCurrentTab(tab)
                updateTabWithCurrentSnapshot(tab)
            case .alerts, .settings:
                if let snapshot = getCurrentSnapshot(),
                   let sensor = dataService.getSensor(
                    for: snapshot.id
                   ) {
                    router.openTagSettings(
                        ruuviTag: sensor,
                        latestMeasurement: snapshot.latestRawRecord,
                        sensorSettings: dataService.getSensorSettings(
                            for: snapshot.id
                           ),
                        output: self
                    )
                }
            }
        } else if flags.showRedesignedCardsUIWithNewMenu {
            currentTab = tab
            view?.updateCurrentTab(tab)
            updateTabWithCurrentSnapshot(tab)
        }
    }

    func viewDidNavigateToSnapshot(at index: Int) {
        handleSnapshotNavigation(to: index)
    }

    func viewDidTriggerRefresh() {
        refreshCurrentData()
    }

    // MARK: - Navigation Handling
    private func handleSnapshotNavigation(to index: Int) {
        guard index >= 0 && index < snapshots.count && index != currentSnapshotIndex else { return }

        currentSnapshotIndex = index
        view?.updateCurrentSnapshotIndex(index)

        if currentTab == .measurement {
            measurementPresenter?.navigateToIndex(index, animated: true)
        }

        updateAllTabsWithCurrentSnapshot()
    }

    private func handleMeasurementTabNavigation(to index: Int) {
        guard index != currentSnapshotIndex,
              index >= 0,
              index < snapshots.count else { return }

        currentSnapshotIndex = index
        view?.updateCurrentSnapshotIndex(currentSnapshotIndex)
        updateOtherTabsWithCurrentSnapshot()
    }

    // MARK: - Safe Resource-Preserving Update Methods
    private func safelyUpdateSnapshot(
        target: RuuviTagCardSnapshot,
        from source: RuuviTagCardSnapshot
    ) {
        let preservedBackground = target.displayData.background
        let preservedVersion = target.displayData.version
        let preservedLatestRecord = target.latestRawRecord

        target.displayData = source.displayData
        target.alertData = source.alertData
        target.connectionData = source.connectionData
        target.metadata = source.metadata
        target.lastUpdated = source.lastUpdated
        target.latestRawRecord = source.latestRawRecord

        if target.displayData.background == nil && preservedBackground != nil {
            target.displayData.background = preservedBackground
        }

        if target.displayData.version == nil && preservedVersion != nil {
            target.displayData.version = preservedVersion
        }

        if target.latestRawRecord == nil && preservedLatestRecord != nil {
            target.latestRawRecord = preservedLatestRecord
        }
    }

    // MARK: - Simplified Thread-Safe Updates
    private func scheduleSnapshotUpdate(_ snapshot: RuuviTagCardSnapshot) {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            self.pendingUpdates[snapshot.id] = snapshot

            self.updateWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.processPendingUpdates()
            }
            self.updateWorkItem = workItem

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
    }

    private func processPendingUpdates() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }

            let updates = self.pendingUpdates
            self.pendingUpdates.removeAll()

            DispatchQueue.main.async {
                for (snapshotId, updatedSnapshot) in updates {
                    self.applySnapshotUpdate(snapshotId: snapshotId, updatedSnapshot: updatedSnapshot)
                }
            }
        }
    }

    private func applySnapshotUpdate(snapshotId: String, updatedSnapshot: RuuviTagCardSnapshot) {
        guard let index = snapshots.firstIndex(where: { $0.id == snapshotId }),
              index >= 0 && index < snapshots.count else {
            return
        }

        safelyUpdateSnapshot(target: snapshots[index], from: updatedSnapshot)
        measurementPresenter?.updateCurrentSnapshot(snapshots[index])

        if index == currentSnapshotIndex && currentTab != .measurement {
            updateTabWithCurrentSnapshot(currentTab)
        }

        view?.updateSnapshots(snapshots)
    }
}

// MARK: - NewCardsModuleInput
extension CardsMainPresenter: NewCardsModuleInput {

    func configure(
        activeSnapshot: RuuviTagCardSnapshot,
        snapshots: [RuuviTagCardSnapshot],
        ruuviTagSensors: [AnyRuuviTagSensor],
        sensorSettings: [SensorSettings],
        activeMenu: CardsMenuType,
        output: NewCardsModuleOutput
    ) {
        hasInitialConfiguration = true
        self.output = output
        self.snapshots = snapshots
        self.ruuviTagSensors = ruuviTagSensors
        self.currentSnapshotIndex = snapshots.firstIndex(of: activeSnapshot) ?? 0
        self.initialActiveMenu = activeMenu
        self.currentTab = activeMenu

        if view != nil {
            applyInitialConfiguration()
        }
    }

    func dismiss(completion: (() -> Void)?) {
        completion?()
    }

    private func applyInitialConfiguration() {
        guard hasInitialConfiguration && !isApplyingInitialConfiguration else { return }

        isApplyingInitialConfiguration = true
        defer { isApplyingInitialConfiguration = false }

        view?.updateSnapshots(snapshots)
        view?.updateCurrentSnapshotIndex(currentSnapshotIndex)
        view?.updateCurrentTab(initialActiveMenu)

        updateAllTabsWithConfiguredData()
        loadMissingBackgrounds()
    }

    private func updateAllTabsWithConfiguredData() {
        let currentSnapshot = getCurrentSnapshot()

        measurementPresenter?.updateSnapshots(snapshots, currentIndex: currentSnapshotIndex)

        if let currentSnapshot,
            let currentSensor = getCurrentSensor() {
            graphPresenter?
                .configure(
                    snapshot: currentSnapshot,
                    sensor: currentSensor
                )
        }

        alertsPresenter?.updateCurrentSnapshot(currentSnapshot)
        settingsPresenter?.updateCurrentSnapshot(currentSnapshot)
    }
}

// MARK: - Tab Presenter Creation
private extension CardsMainPresenter {

    func createTabPresenters() {
        if let measurementVC = tabControllers[.measurement] as? CardsMeasurementViewController {
            measurementPresenter = CardsMeasurementPresenter(
                dataService: dataService,
                alertService: alertService,
                settings: settings
            )
            measurementPresenter?.view = measurementVC
            measurementVC.output = measurementPresenter

            measurementPresenter?.onSnapshotIndexChanged = { [weak self] newIndex in
                self?.handleMeasurementTabNavigation(to: newIndex)
            }
        }

        if let graphVC = tabControllers[.graph] as? CardsGraphViewController {
            // Create the service factory with full dependencies
            let r = AppAssembly.shared.assembler.resolver
            let serviceFactory = CardsGraphServiceFactoryImpl(
                resolver: r
            )

            graphPresenter = serviceFactory.createPresenter(view: graphVC)
            graphVC.output = graphPresenter
            graphVC.measurementService = r.resolve(RuuviServiceMeasurement.self)!
        }

        if let alertsVC = tabControllers[.alerts] as? CardsAlertsViewController {
            alertsPresenter = CardsAlertsPresenter(
                alertService: alertService,
                settings: settings
            )
            alertsPresenter?.view = alertsVC
            alertsVC.output = alertsPresenter
        }

        if let settingsVC = tabControllers[.settings] as? CardsSettingsViewController {
            settingsPresenter = CardsSettingsPresenter(
                dataService: dataService,
                settings: settings
            )
            settingsPresenter?.view = settingsVC
            settingsVC.output = settingsPresenter
        }

        if hasInitialConfiguration {
            updateAllTabsWithConfiguredData()
        }
    }

    func updateTabWithCurrentSnapshot(_ tab: CardsMenuType) {
        let currentSnapshot = getCurrentSnapshot()

        switch tab {
        case .measurement:
            measurementPresenter?.updateSnapshots(snapshots, currentIndex: currentSnapshotIndex)
        case .graph:
            if let currentSnapshot, let currentSensor = getCurrentSensor() {
                graphPresenter?.scrollTo(
                        snapshot: currentSnapshot,
                        sensor: currentSensor
                    )
            }
        case .alerts:
            alertsPresenter?.updateCurrentSnapshot(currentSnapshot)
        case .settings:
            settingsPresenter?.updateCurrentSnapshot(currentSnapshot)
        }
    }

    func updateAllTabsWithCurrentSnapshot() {
        guard currentSnapshotIndex >= 0 && currentSnapshotIndex < snapshots.count else {
            return
        }

        let currentSnapshot = snapshots[currentSnapshotIndex]

        switch currentTab {
        case .measurement:
            measurementPresenter?.updateSnapshots(snapshots, currentIndex: currentSnapshotIndex)
        case .graph:
            if let currentSensor = getCurrentSensor() {
                graphPresenter?.scrollTo(
                        snapshot: currentSnapshot,
                        sensor: currentSensor
                    )
            }
        case .alerts:
            alertsPresenter?.updateCurrentSnapshot(currentSnapshot)
        case .settings:
            settingsPresenter?.updateCurrentSnapshot(currentSnapshot)
        }
    }

    func updateOtherTabsWithCurrentSnapshot() {
        guard currentSnapshotIndex >= 0 && currentSnapshotIndex < snapshots.count else {
            return
        }

        let currentSnapshot = snapshots[currentSnapshotIndex]

        switch currentTab {
        case .measurement:
            break
        case .graph:
            if let currentSensor = getCurrentSensor() {
                graphPresenter?.scrollTo(
                        snapshot: currentSnapshot,
                        sensor: currentSensor
                    )
            }
        case .alerts:
            alertsPresenter?.updateCurrentSnapshot(currentSnapshot)
        case .settings:
            settingsPresenter?.updateCurrentSnapshot(currentSnapshot)
        }
    }
}

// MARK: - Data Management
private extension CardsMainPresenter {

    func loadInitialData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let initialSnapshots = self.dataService.getAllSnapshots()

            DispatchQueue.main.async {
                self.updateSnapshots(initialSnapshots)
            }
        }
    }

    func refreshCurrentData() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let refreshedSnapshots = self.dataService.getAllSnapshots()

            DispatchQueue.main.async {
                self.updateSnapshots(refreshedSnapshots)
            }
        }
    }

    func updateSnapshots(_ newSnapshots: [RuuviTagCardSnapshot]) {
        snapshots = newSnapshots

        if currentSnapshotIndex >= snapshots.count {
            currentSnapshotIndex = max(0, snapshots.count - 1)
        }

        view?.updateSnapshots(newSnapshots)
        view?.updateCurrentSnapshotIndex(currentSnapshotIndex)
        updateTabWithCurrentSnapshot(currentTab)
    }

    func loadMissingBackgrounds() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let sensors = self.dataService.getAllSensors()
            let snapshotsNeedingBackgrounds = self.snapshots.filter { snapshot in
                snapshot.displayData.background == nil
            }

            if !snapshotsNeedingBackgrounds.isEmpty {
                self.backgroundService.loadBackgrounds(for: snapshotsNeedingBackgrounds, sensors: sensors)
            }
        }
    }
}

// MARK: - Service Delegates
private extension CardsMainPresenter {

    func setupServiceDelegates() {
        dataService.delegate = self
        alertService.delegate = self
        backgroundService.delegate = self
        connectionService.delegate = self
        dashboardCloudSyncService.delegate = self
    }
}

// MARK: - Service Delegate Implementations
extension CardsMainPresenter: RuuviTagDataServiceDelegate {

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    ) {
        guard !isApplyingInitialConfiguration else { return }

        if hasInitialConfiguration {
            var updatedSnapshots = self.snapshots
            for snapshot in updatedSnapshots {
                if let newSnapshot = snapshots.first(where: { $0.id == snapshot.id }) {
                    safelyUpdateSnapshot(target: snapshot, from: newSnapshot)
                }
            }

            for newSnapshot in snapshots {
                if !updatedSnapshots.contains(where: { $0.id == newSnapshot.id }) {
                    updatedSnapshots.append(newSnapshot)
                }
            }

            self.snapshots = updatedSnapshots
        } else {
            self.snapshots = snapshots
            if currentSnapshotIndex >= snapshots.count {
                currentSnapshotIndex = max(0, snapshots.count - 1)
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.measurementPresenter?.updateSnapshots(self.snapshots, currentIndex: self.currentSnapshotIndex)
            self.view?.updateSnapshots(self.snapshots)
            self.view?.updateCurrentSnapshotIndex(self.currentSnapshotIndex)
        }

        loadMissingBackgrounds()
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    ) {
        scheduleSnapshotUpdate(snapshot)
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didAddNewSensor sensor: RuuviTagSensor,
        newOrder: [String]
    ) {
        if !hasInitialConfiguration {
            refreshCurrentData()
        }
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didEncounterError error: Error
    ) {

    }
}

extension CardsMainPresenter: RuuviTagAlertServiceDelegate {

    func alertService(
        _ service: RuuviTagAlertService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        do {
            scheduleSnapshotUpdate(snapshot)
        } catch {
            print("Error updating alert snapshot: \(error)")
        }
    }

    func alertService(
        _ service: RuuviTagAlertService,
        alertsDidChange: Bool
    ) {
        // No action needed
    }
}

// MARK: - FIXED: Background Service Delegate with Proper View Updates
extension CardsMainPresenter: RuuviTagBackgroundServiceDelegate {

    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        print("CardsMainPresenter: Background service updated snapshot \(snapshot.id)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applyBackgroundUpdate(snapshot)
        }
    }

    // FIXED: Enhanced background update method
    private func applyBackgroundUpdate(_ snapshot: RuuviTagCardSnapshot) {
        guard let index = snapshots.firstIndex(where: { $0.id == snapshot.id }),
              index >= 0 && index < snapshots.count else {
            print("CardsMainPresenter: Cannot find snapshot for background update with ID: \(snapshot.id)")
            return
        }

        let oldBackground = snapshots[index].displayData.background
        let newBackground = snapshot.displayData.background

        print("CardsMainPresenter: Updating background for snapshot \(snapshot.id)")
        print("  Old background: \(oldBackground != nil ? "present" : "nil")")
        print("  New background: \(newBackground != nil ? "present" : "nil")")

        if let newBackground = newBackground {
            // Update the background in our snapshot
            snapshots[index].displayData.background = newBackground

            // Update measurement presenter immediately
            measurementPresenter?.updateCurrentSnapshot(snapshots[index])

            // Update other tabs if this is the current snapshot
            if index == currentSnapshotIndex && currentTab != .measurement {
                updateTabWithCurrentSnapshot(currentTab)
            }

            // FIXED: Always call updateSnapshots to trigger view refresh
            print("CardsMainPresenter: Triggering view update for background change")
            view?.updateSnapshots(snapshots)

            // FIXED: Also trigger a force refresh for the landing view if available
            if let landingView = view as? NewCardsLandingViewController {
                landingView.forceBackgroundRefresh()
            }
        } else {
            print("CardsMainPresenter: Warning - Background update has nil background image")
        }
    }

    func backgroundService(
        _ service: RuuviTagBackgroundService,
        didEncounterError error: Error
    ) {
    }
}

extension CardsMainPresenter: RuuviTagConnectionServiceDelegate {

    func connectionService(
        _ service: RuuviTagConnectionService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        scheduleSnapshotUpdate(snapshot)
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        bluetoothStateChanged isEnabled: Bool,
        userDeclined: Bool
    ) {
        if !isEnabled || userDeclined {
            DispatchQueue.main.async { [weak self] in
                self?.view?.showBluetoothDisabled(userDeclined: userDeclined)
            }
        }
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        didEncounterError error: Error
    ) {
    }
}

extension CardsMainPresenter: RuuviCloudServiceDelegate {
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
        switch currentTab {
        case .measurement, .alerts, .settings:
            view?.isRefreshing = isRefreshing
        default:
            break
        }
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        historySyncInProgress inProgress: Bool,
        for macId: String
    ) {
        switch currentTab {
        case .graph:
            if let currentSnapshot = getCurrentSnapshot(),
                currentSnapshot.identifierData.mac?.value == macId {
                view?.isRefreshing = inProgress
            }
        default:
            break
        }
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncDidComplete: Bool
    ) {
        //
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

extension CardsMainPresenter: TagSettingsModuleOutput {
    func tagSettingsDidDeleteTag(
        module: TagSettingsModuleInput,
        ruuviTag: RuuviTagSensor
    ) {
        module.dismiss(completion: { [weak self] in
            guard let self else { return }
//            view?.dismissChart()
//            output?.cardsViewDidRefresh(module: self)
//            if let index = viewModels.firstIndex(where: {
//                ($0.luid != nil && $0.luid == ruuviTag.luid?.any) ||
//                    ($0.mac != nil && $0.mac == ruuviTag.macId?.any)
//            }) {
//                viewModels.remove(at: index)
//                view?.viewModels = viewModels
//            }
//
//            if viewModels.count > 0,
//               let first = viewModels.first {
//                updateVisibleCard(from: first, triggerScroll: true)
//            } else {
//                viewShouldDismiss()
//            }
        })
    }

    func tagSettingsDidDismiss(module: TagSettingsModuleInput) {
        module.dismiss(completion: nil)
    }
}
