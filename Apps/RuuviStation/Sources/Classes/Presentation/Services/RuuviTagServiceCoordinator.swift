// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviReactor
import RuuviStorage
import RuuviService
import RuuviDaemon
import RuuviUser
import RuuviCore
import RuuviNotifier
import RuuviLocal
import BTKit

// MARK: - Snapshot Update Reason
enum SnapshotUpdateReason {
    case initial                                    // First load
    case reorder                                   // Order changed
    case insert([RuuviTagCardSnapshot])           // New items added
    case delete([RuuviTagCardSnapshot])           // Items removed
    case update([RuuviTagCardSnapshot])           // Values changed
    case mixed(
        inserted: [RuuviTagCardSnapshot],
        // Multiple changes
        deleted: [RuuviTagCardSnapshot],
        updated: [RuuviTagCardSnapshot],
        reordered: Bool
    )
}

// MARK: - RuuviTagServiceCoordinatorEvent
enum RuuviTagServiceCoordinatorEvent {
    case snapshotsUpdated(
        [RuuviTagCardSnapshot],
        reason: SnapshotUpdateReason,
        withAnimation: Bool
    )

    // Individual snapshot events
    case snapshotUpdated(RuuviTagCardSnapshot, invalidateLayout: Bool)
    case newSensorAdded(RuuviTagSensor, newOrder: [String])
    case dataServiceError(Error)

    // Cloud Service Events
    case userLoginStateChanged(Bool)
    case userLogoutStateChanged(Bool)
    case cloudSyncStatusChanged(Bool)
    case cloudSyncCompleted
    case historySyncInProgress(Bool, macId: String)
    case authorizationFailed
    case cloudModeChanged(Bool)

    // Alert Service Events
    case alertSnapshotUpdated(RuuviTagCardSnapshot)
    case alertsChanged

    // Connection Service Events
    case connectionSnapshotUpdated(RuuviTagCardSnapshot)
    case bluetoothStateChanged(isEnabled: Bool, userDeclined: Bool)
    case connectionServiceError(Error)
}

// MARK: - RuuviTagServiceCoordinatorObserver
protocol RuuviTagServiceCoordinatorObserver: AnyObject {
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    )
}

// MARK: - RuuviTagServiceCoordinator
class RuuviTagServiceCoordinator {

    // MARK: - Services
    private let dataService: RuuviTagDataService
    private let cloudService: RuuviCloudService
    private let alertService: RuuviTagAlertService
    private let connectionService: RuuviTagConnectionService

    // MARK: - Observer Management
    private var observers: [WeakObserverWrapper] = []
    private let observersQueue = DispatchQueue(
        label: "com.ruuvi.coordinator.observers",
        attributes: .concurrent
    )
    private var cleanupTimer: Timer?

    // MARK: - State
    private var isStarted = false
    private var initialSetupCompleted = false

    // MARK: - Snapshot Tracking
    private var previousSnapshots: [RuuviTagCardSnapshot] = []
    private var snapshotIdMap: [String: RuuviTagCardSnapshot] = [:]

    // MARK: - Initialization
    init(
        dataService: RuuviTagDataService,
        cloudService: RuuviCloudService,
        alertService: RuuviTagAlertService,
        connectionService: RuuviTagConnectionService
    ) {
        self.dataService = dataService
        self.cloudService = cloudService
        self.alertService = alertService
        self.connectionService = connectionService

        setupServiceDelegates()
        startPeriodicObserverCleanup()
    }

    deinit {
        stop()
        cleanupTimer?.invalidate()
    }

    // MARK: - Observer Management
    func addObserver(_ observer: RuuviTagServiceCoordinatorObserver) {
        observersQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            // Remove any existing observer to prevent duplicates
            self.observers.removeAll { $0.observer === observer }

            // Add new observer
            self.observers.append(WeakObserverWrapper(observer: observer))

            DispatchQueue.main.async {
                self.sendCurrentStateToObserver(observer)
            }
        }
    }

    func removeObserver(_ observer: RuuviTagServiceCoordinatorObserver) {
        observersQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.observers.removeAll { $0.observer === observer }
        }
    }

    func forceLoadBackgrounds() {
        dataService.loadBackgroundsForCurrentSnapshots()
    }

    private func sendCurrentStateToObserver(_ observer: RuuviTagServiceCoordinatorObserver) {
        guard isStarted else { return }

        let snapshots = dataService.getAllSnapshots()

        // Only send if we have data
        if !snapshots.isEmpty {
            let reason: SnapshotUpdateReason = initialSetupCompleted ? .update([]) : .initial
            observer.coordinatorDidReceiveEvent(
                self,
                event: .snapshotsUpdated(
                    snapshots,
                    reason: reason,
                    withAnimation: false
                )
            )
        }

        // Send current cloud state
        observer.coordinatorDidReceiveEvent(self, event: .cloudModeChanged(cloudService.isCloudModeEnabled()))
        observer.coordinatorDidReceiveEvent(self, event: .userLoginStateChanged(cloudService.isAuthorized()))

        // Send current bluetooth state
        let (isEnabled, userDeclined) = connectionService.getCurrentBluetoothState()
        observer.coordinatorDidReceiveEvent(
            self, event: .bluetoothStateChanged(isEnabled: isEnabled, userDeclined: userDeclined)
        )
    }

    private func startPeriodicObserverCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupObservers()
        }
    }

    private func cleanupObservers() {
        observersQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.observers = self.observers.filter { $0.observer != nil }
        }
    }

    func getObserverCount() -> Int {
        return observersQueue.sync {
            observers.compactMap { $0.observer }.count
        }
    }

    // MARK: - Public Interface
    func start() {
        guard !isStarted else { return }

        isStarted = true

        dataService.startObservingSensors()
        cloudService.startObserving()
        alertService.startObservingAlerts()
        connectionService.startObservingConnections()

        // Defer initial setup to avoid race conditions
        DispatchQueue.main.async { [weak self] in
            self?.performInitialSetup()
        }
    }

    func stop() {
        guard isStarted else { return }

        isStarted = false
        initialSetupCompleted = false
        previousSnapshots = []
        snapshotIdMap = [:]

        dataService.stopObservingSensors()
        cloudService.stopObserving()
        alertService.stopObservingAlerts()
        connectionService.stopObservingConnections()
    }

    private func performInitialSetup() {
        let snapshots = dataService.getAllSnapshots()
        guard !snapshots.isEmpty else {
            // If no snapshots yet, wait for the data service to load them
            // The delegate method will handle the initial setup
            return
        }

        guard !initialSetupCompleted else { return }
        initialSetupCompleted = true

        // Store initial state
        previousSnapshots = snapshots
        updateSnapshotIdMap(snapshots)

        alertService.subscribeToAlerts(for: snapshots)
        connectionService.updateConnectionData(for: snapshots)

        notifySnapshotChange(snapshots, reason: .initial, withAnimation: false)
    }

    // MARK: - Service Access
    // swiftlint:disable:next large_tuple
    var services: (
        data: RuuviTagDataService,
        cloud: RuuviCloudService,
        alert: RuuviTagAlertService,
        connection: RuuviTagConnectionService
    ) {
        return (
            data: dataService,
            cloud: cloudService,
            alert: alertService,
            connection: connectionService
        )
    }

    // MARK: - Convenience Methods
    func getAllSnapshots() -> [RuuviTagCardSnapshot] {
        return dataService.getAllSnapshots()
    }

    func getSnapshot(for sensorId: String) -> RuuviTagCardSnapshot? {
        return dataService.getSnapshot(for: sensorId)
    }

    func getAllSensors() -> [AnyRuuviTagSensor] {
        return dataService.getAllSensors()
    }

    func getSensorSettings() -> [SensorSettings] {
        return dataService.getSensorSettings()
    }

    func getSensor(for sensorId: String) -> AnyRuuviTagSensor? {
        return dataService.getSensor(for: sensorId)
    }

    func triggerCloudSync() {
        cloudService.triggerImmediateSync()
    }

    func triggerFullHistorySync() {
        cloudService.triggerFullHistorySync()
    }

    func setKeepConnection(_ keep: Bool, for snapshot: RuuviTagCardSnapshot) {
        connectionService.setKeepConnection(keep, for: snapshot)
    }

    func updateSensorName(_ name: String, for snapshot: RuuviTagCardSnapshot) {
        dataService.snapshotSensorNameDidChange(to: name, for: snapshot)
    }

    func isCloudModeEnabled() -> Bool {
        return cloudService.isCloudModeEnabled()
    }

    func isCloudAuthorized() -> Bool {
        return cloudService.isAuthorized()
    }

    func getUserEmail() -> String? {
        return cloudService.getUserEmail()
    }

    func forceCloudLogout() {
        cloudService.forceLogout()
    }

    func reorderSnapshots(with orderedIds: [String]) {
        dataService.reorderSnapshots(with: orderedIds)
    }

    // MARK: - Alert Management
    func syncAllAlerts(for snapshot: RuuviTagCardSnapshot, physicalSensor: PhysicalSensor) {
        alertService.syncAllAlerts(for: snapshot, physicalSensor: physicalSensor)
    }

    func processAlert(record: RuuviTagSensorRecord, snapshot: RuuviTagCardSnapshot) {
        alertService.processAlert(record: record, snapshot: snapshot)
    }

    func triggerAlertsIfNeeded(for snapshots: [RuuviTagCardSnapshot]) {
        alertService.triggerAlertsIfNeeded(for: snapshots)
    }

    // MARK: - Connection Management
    func updateConnectionData(for snapshots: [RuuviTagCardSnapshot]) {
        connectionService.updateConnectionData(for: snapshots)
    }

    func getConnectionStatus(for snapshot: RuuviTagCardSnapshot) -> (isConnected: Bool, keepConnection: Bool) {
        return connectionService.getConnectionStatus(for: snapshot)
    }

    func getCurrentBluetoothState() -> (isEnabled: Bool, userDeclined: Bool) {
        return connectionService.getCurrentBluetoothState()
    }

    func shouldShowBluetoothAlert(for snapshots: [RuuviTagCardSnapshot]) -> Bool {
        return connectionService.shouldShowBluetoothAlert(for: snapshots)
    }
}

// MARK: - Private Implementation
private extension RuuviTagServiceCoordinator {

    func setupServiceDelegates() {
        dataService.delegate = self
        cloudService.delegate = self
        alertService.delegate = self
        connectionService.delegate = self
    }

    // MARK: - Snapshot Change Detection
    func detectSnapshotChanges(_ newSnapshots: [RuuviTagCardSnapshot]) -> SnapshotUpdateReason {
        // Initial load case
        if previousSnapshots.isEmpty && !newSnapshots.isEmpty {
            return .initial
        }

        let oldIds = Set(previousSnapshots.map { $0.id })
        let newIds = Set(newSnapshots.map { $0.id })

        // Detect insertions and deletions
        let insertedIds = newIds.subtracting(oldIds)
        let deletedIds = oldIds.subtracting(newIds)

        let inserted = newSnapshots.filter { insertedIds.contains($0.id) }
        let deleted = previousSnapshots.filter { deletedIds.contains($0.id) }

        // Detect updates (comparing snapshots with same ID)
        var updated: [RuuviTagCardSnapshot] = []
        for snapshot in newSnapshots {
            if let oldSnapshot = snapshotIdMap[snapshot.id],
               oldIds.contains(snapshot.id),
               hasSnapshotChanged(old: oldSnapshot, new: snapshot) {
                updated.append(snapshot)
            }
        }

        // Detect reorder (if no insertions/deletions but order changed)
        let reordered = detectReorder(oldSnapshots: previousSnapshots, newSnapshots: newSnapshots)

        // Determine the reason
        if inserted.isEmpty && deleted.isEmpty && updated.isEmpty && reordered {
            return .reorder
        } else if !inserted.isEmpty && deleted.isEmpty && updated.isEmpty && !reordered {
            return .insert(inserted)
        } else if inserted.isEmpty && !deleted.isEmpty && updated.isEmpty && !reordered {
            return .delete(deleted)
        } else if inserted.isEmpty && deleted.isEmpty && !updated.isEmpty && !reordered {
            return .update(updated)
        } else if !inserted.isEmpty || !deleted.isEmpty || !updated.isEmpty || reordered {
            return .mixed(
                inserted: inserted,
                deleted: deleted,
                updated: updated,
                reordered: reordered
            )
        }

        // No changes
        return .update([])
    }

    func detectReorder(oldSnapshots: [RuuviTagCardSnapshot], newSnapshots: [RuuviTagCardSnapshot]) -> Bool {
        // Only check reorder if counts are same
        guard oldSnapshots.count == newSnapshots.count else { return false }

        let oldIds = oldSnapshots.map { $0.id }
        let newIds = newSnapshots.map { $0.id }

        // Check if same elements but different order
        return Set(oldIds) == Set(newIds) && oldIds != newIds
    }

    func hasSnapshotChanged(old: RuuviTagCardSnapshot, new: RuuviTagCardSnapshot) -> Bool {
        // Compare relevant properties that indicate a value change
        // You can customize this based on what properties matter
        return old.latestRawRecord?.date != new.latestRawRecord?.date ||
               old.displayData.name != new.displayData.name ||
               old.displayData.background != new.displayData.background ||
               old.metadata.isOwner != new.metadata.isOwner ||
               old.metadata.isCloud != new.metadata.isCloud
    }

    func updateSnapshotIdMap(_ snapshots: [RuuviTagCardSnapshot]) {
        snapshotIdMap = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
    }

    func notifySnapshotChange(
        _ snapshots: [RuuviTagCardSnapshot],
        reason: SnapshotUpdateReason,
        withAnimation: Bool
    ) {
        // Update tracking state
        previousSnapshots = snapshots
        updateSnapshotIdMap(snapshots)

        // Send new detailed event
        notifyEvent(.snapshotsUpdated(
            snapshots,
            reason: reason,
            withAnimation: withAnimation
        ))
    }

    func notifyEvent(_ event: RuuviTagServiceCoordinatorEvent) {
        // Always notify on main thread to ensure consistent ordering
        if Thread.isMainThread {
            performNotification(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.performNotification(event)
            }
        }
    }

    private func performNotification(_ event: RuuviTagServiceCoordinatorEvent) {
        // Read observers without blocking
        observersQueue.async { [weak self] in
            guard let self = self else { return }

            // Get current observers
            let activeObservers = self.observers.compactMap { $0.observer }

            // Notify on main thread
            DispatchQueue.main.async {
                for observer in activeObservers {
                    observer.coordinatorDidReceiveEvent(self, event: event)
                }
            }
        }
    }
}

// MARK: - Service Delegate Implementations
extension RuuviTagServiceCoordinator: RuuviTagDataServiceDelegate {

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshots snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    ) {
        // Detect what changed
        let reason = detectSnapshotChanges(snapshots)

        // Update other services with new snapshots
        alertService.updateSnapshots(snapshots)
        connectionService.updateConnectionData(for: snapshots)

        // Perform initial setup if not done yet
        if !initialSetupCompleted && !snapshots.isEmpty {
            initialSetupCompleted = true
            previousSnapshots = snapshots
            updateSnapshotIdMap(snapshots)
            alertService.subscribeToAlerts(for: snapshots)
            alertService.triggerAlertsIfNeeded(for: snapshots)
        }

        notifySnapshotChange(snapshots, reason: reason, withAnimation: withAnimation)
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    ) {
        // Update the snapshot in our tracking map
        snapshotIdMap[snapshot.id] = snapshot

        // Update the snapshot in previousSnapshots if it exists
        if let index = previousSnapshots.firstIndex(where: { $0.id == snapshot.id }) {
            previousSnapshots[index] = snapshot
        }

        notifyEvent(.snapshotUpdated(snapshot, invalidateLayout: invalidateLayout))
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didAddNewSensor sensor: RuuviTagSensor,
        newOrder: [String]
    ) {
        // Update other services when new sensor is added
        let snapshots = dataService.getAllSnapshots()
        alertService.subscribeToAlerts(for: snapshots)
        connectionService.updateConnectionData(for: snapshots)

        // Update tracking
        previousSnapshots = snapshots
        updateSnapshotIdMap(snapshots)

        notifyEvent(.newSensorAdded(sensor, newOrder: newOrder))
    }

    func sensorDataService(
        _ service: RuuviTagDataService,
        didEncounterError error: Error
    ) {
        notifyEvent(.dataServiceError(error))
    }
}

extension RuuviTagServiceCoordinator: RuuviCloudServiceDelegate {

    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogin loggedIn: Bool
    ) {
        notifyEvent(.userLoginStateChanged(loggedIn))
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        userDidLogOut loggedOut: Bool
    ) {
        notifyEvent(.userLogoutStateChanged(loggedOut))
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncStatusDidChange isRefreshing: Bool
    ) {
        notifyEvent(.cloudSyncStatusChanged(isRefreshing))
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        syncDidComplete: Bool
    ) {
        notifyEvent(.cloudSyncCompleted)
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        historySyncInProgress inProgress: Bool,
        for macId: String
    ) {
        notifyEvent(.historySyncInProgress(inProgress, macId: macId))
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        authorizationFailed: Bool
    ) {
        notifyEvent(.authorizationFailed)
    }

    func ruuviCloudService(
        _ service: RuuviCloudService,
        cloudModeDidChange isEnabled: Bool
    ) {
        notifyEvent(.cloudModeChanged(isEnabled))
    }
}

extension RuuviTagServiceCoordinator: RuuviTagAlertServiceDelegate {

    func alertService(
        _ service: RuuviTagAlertService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        notifyEvent(.alertSnapshotUpdated(snapshot))
    }

    func alertService(
        _ service: RuuviTagAlertService,
        alertsDidChange: Bool
    ) {
        notifyEvent(.alertsChanged)
        if alertsDidChange {
            // Trigger alerts if needed
            service
                .triggerAlertsIfNeeded(
                    for: getAllSnapshots()
                )
        }
    }
}

extension RuuviTagServiceCoordinator: RuuviTagConnectionServiceDelegate {

    func connectionService(
        _ service: RuuviTagConnectionService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    ) {
        notifyEvent(.connectionSnapshotUpdated(snapshot))
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        bluetoothStateChanged isEnabled: Bool,
        userDeclined: Bool
    ) {
        notifyEvent(.bluetoothStateChanged(isEnabled: isEnabled, userDeclined: userDeclined))
    }

    func connectionService(
        _ service: RuuviTagConnectionService,
        didEncounterError error: Error
    ) {
        notifyEvent(.connectionServiceError(error))
    }
}

// MARK: - WeakObserverWrapper
private class WeakObserverWrapper {
    weak var observer: RuuviTagServiceCoordinatorObserver?

    init(observer: RuuviTagServiceCoordinatorObserver) {
        self.observer = observer
    }
}

// MARK: - RuuviTagServiceCoordinatorManager (Singleton)
class RuuviTagServiceCoordinatorManager {

    // MARK: - Singleton
    static let shared = RuuviTagServiceCoordinatorManager()

    // MARK: - Coordinator Instance
    private var coordinator: RuuviTagServiceCoordinator?
    private let coordinatorQueue = DispatchQueue(
        label: "com.ruuvi.coordinator.manager",
        attributes: .concurrent
    )

    // MARK: - Initialization State
    private var isInitialized = false

    // MARK: - Private Initialization
    private init() {}

    // MARK: - Coordinator Initialization
    func initialize() {
        coordinatorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self.isInitialized else { return }

            self.coordinator = RuuviTagCoordinatorFactory.createCoordinator()
            self.isInitialized = true

            DispatchQueue.main.async {
                self.coordinator?.start()
            }
        }
    }

    func reset() {
        coordinatorQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.coordinator?.stop()
            }

            self.coordinator = nil
            self.isInitialized = false
        }
    }

    // MARK: - Observer Management
    func addObserver(_ observer: RuuviTagServiceCoordinatorObserver) {
        coordinatorQueue.async { [weak self] in
            self?.coordinator?.addObserver(observer)
        }
    }

    func removeObserver(_ observer: RuuviTagServiceCoordinatorObserver) {
        coordinatorQueue.sync { [weak self] in
            self?.coordinator?.removeObserver(observer)
        }
    }

    // MARK: - Coordinator Access
    func withCoordinator<T>(_ block: (RuuviTagServiceCoordinator) -> T) -> T? {
        return coordinatorQueue.sync { [weak self] in
            guard let coordinator = self?.coordinator else { return nil }
            return block(coordinator)
        }
    }

    func withCoordinatorAsync<T>(
        _ block: @escaping (RuuviTagServiceCoordinator) -> T,
        completion: @escaping (T?) -> Void
    ) {
        coordinatorQueue.async { [weak self] in
            guard let coordinator = self?.coordinator else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let result = block(coordinator)
            DispatchQueue.main.async { completion(result) }
        }
    }

    // MARK: - Status
    var isCoordinatorInitialized: Bool {
        return coordinatorQueue.sync { isInitialized }
    }

    var observerCount: Int {
        return coordinatorQueue.sync { coordinator?.getObserverCount() ?? 0 }
    }

    // MARK: - Convenience Methods (Proxy to Coordinator)
    func getAllSnapshots() -> [RuuviTagCardSnapshot] {
        return withCoordinator { $0.getAllSnapshots() } ?? []
    }

    func getSnapshot(for sensorId: String) -> RuuviTagCardSnapshot? {
        return withCoordinator { $0.getSnapshot(for: sensorId) } ?? nil
    }

    func getAllSensors() -> [AnyRuuviTagSensor] {
        return withCoordinator { $0.getAllSensors() } ?? []
    }

    func getSensor(for sensorId: String) -> AnyRuuviTagSensor? {
        return withCoordinator { $0.getSensor(for: sensorId) } ?? nil
    }

    func getSensorSettings() -> [SensorSettings] {
        return withCoordinator { $0.getSensorSettings() } ?? []
    }

    func triggerCloudSync() {
        withCoordinator { $0.triggerCloudSync() }
    }

    func triggerFullHistorySync() {
        withCoordinator { $0.triggerFullHistorySync() }
    }

    func setKeepConnection(_ keep: Bool, for snapshot: RuuviTagCardSnapshot) {
        withCoordinator { $0.setKeepConnection(keep, for: snapshot) }
    }

    func updateSensorName(_ name: String, for snapshot: RuuviTagCardSnapshot) {
        withCoordinator { $0.updateSensorName(name, for: snapshot) }
    }

    func isCloudModeEnabled() -> Bool {
        return withCoordinator { $0.isCloudModeEnabled() } ?? false
    }

    func isCloudAuthorized() -> Bool {
        return withCoordinator { $0.isCloudAuthorized() } ?? false
    }

    func getUserEmail() -> String? {
        return withCoordinator { $0.getUserEmail() ?? "" }
    }

    func forceCloudLogout() {
        withCoordinator { $0.forceCloudLogout() }
    }

    func reorderSnapshots(with orderedIds: [String]) {
        withCoordinator { $0.reorderSnapshots(with: orderedIds) }
    }

    func forceLoadBackgrounds() {
        withCoordinator { $0.forceLoadBackgrounds() }
    }

    // MARK: - Alert Management
    func syncAllAlerts(for snapshot: RuuviTagCardSnapshot, physicalSensor: PhysicalSensor) {
        withCoordinator { $0.syncAllAlerts(for: snapshot, physicalSensor: physicalSensor) }
    }

    func processAlert(record: RuuviTagSensorRecord, snapshot: RuuviTagCardSnapshot) {
        withCoordinator { $0.processAlert(record: record, snapshot: snapshot) }
    }

    func triggerAlertsIfNeeded(for snapshots: [RuuviTagCardSnapshot]) {
        withCoordinator { $0.triggerAlertsIfNeeded(for: snapshots) }
    }

    // MARK: - Connection Management
    func updateConnectionData(for snapshots: [RuuviTagCardSnapshot]) {
        withCoordinator { $0.updateConnectionData(for: snapshots) }
    }

    func getConnectionStatus(for snapshot: RuuviTagCardSnapshot) -> (isConnected: Bool, keepConnection: Bool) {
        return withCoordinator { $0.getConnectionStatus(for: snapshot) } ?? (false, false)
    }

    func getCurrentBluetoothState() -> (isEnabled: Bool, userDeclined: Bool) {
        return withCoordinator { $0.getCurrentBluetoothState() } ?? (false, false)
    }

    func shouldShowBluetoothAlert(for snapshots: [RuuviTagCardSnapshot]) -> Bool {
        return withCoordinator { $0.shouldShowBluetoothAlert(for: snapshots) } ?? false
    }
}

// MARK: - RuuviTagCoordinatorFactory
class RuuviTagCoordinatorFactory {

    // MARK: - Factory Method
    static func createCoordinator() -> RuuviTagServiceCoordinator {

        let r = AppAssembly.shared.assembler.resolver

        let dataService = RuuviTagDataService(
            ruuviReactor: r.resolve(RuuviReactor.self)!,
            ruuviStorage: r.resolve(RuuviStorage.self)!,
            measurementService: r.resolve(RuuviServiceMeasurement.self)!,
            ruuviSensorPropertiesService: r.resolve(RuuviServiceSensorProperties.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!,
            flags: r.resolve(RuuviLocalFlags.self)!
        )

        let alertService = RuuviTagAlertService(
            alertService: r.resolve(RuuviServiceAlert.self)!,
            alertHandler: r.resolve(RuuviNotifier.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!
        )

        let connectionService = RuuviTagConnectionService(
            foreground: r.resolve(BTForeground.self)!,
            background: r.resolve(BTBackground.self)!,
            connectionPersistence: r.resolve(RuuviLocalConnections.self)!,
            localSyncState: r.resolve(RuuviLocalSyncState.self)!
        )

        let ruuviCloudService = RuuviCloudService(
            cloudSyncDaemon: r.resolve(RuuviDaemonCloudSync.self)!,
            cloudSyncService: r.resolve(RuuviServiceCloudSync.self)!,
            cloudNotificationService: r.resolve(RuuviServiceCloudNotification.self)!,
            authService: r.resolve(RuuviServiceAuth.self)!,
            ruuviUser: r.resolve(RuuviUser.self)!,
            settings: r.resolve(RuuviLocalSettings.self)!,
            pnManager: r.resolve(RuuviCorePN.self)!
        )

        // Create and return coordinator
        return RuuviTagServiceCoordinator(
            dataService: dataService,
            cloudService: ruuviCloudService,
            alertService: alertService,
            connectionService: connectionService
        )
    }
}

// MARK: - Event Filtering
struct RuuviTagServiceCoordinatorEventFilter {
    let includeDataEvents: Bool
    let includeCloudEvents: Bool
    let includeAlertEvents: Bool
    let includeConnectionEvents: Bool
    let specificEvents: Set<RuuviTagCoordinatorEventType>?

    init(
        includeDataEvents: Bool = true,
        includeCloudEvents: Bool = true,
        includeAlertEvents: Bool = true,
        includeConnectionEvents: Bool = true,
        specificEvents: Set<RuuviTagCoordinatorEventType>? = nil
    ) {
        self.includeDataEvents = includeDataEvents
        self.includeCloudEvents = includeCloudEvents
        self.includeAlertEvents = includeAlertEvents
        self.includeConnectionEvents = includeConnectionEvents
        self.specificEvents = specificEvents
    }

    func shouldInclude(_ event: RuuviTagServiceCoordinatorEvent) -> Bool {
        let eventType = event.eventType

        // Check specific events filter first
        if let specificEvents = specificEvents {
            return specificEvents.contains(eventType)
        }

        // Check category filters
        switch eventType {
        case .snapshotsUpdated,
             .snapshotUpdated, .newSensorAdded, .dataServiceError:
            return includeDataEvents
        case .userLoginStateChanged, .userLogoutStateChanged, .cloudSyncStatusChanged,
                .cloudSyncCompleted, .historySyncInProgress, .authorizationFailed, .cloudModeChanged:
            return includeCloudEvents
        case .alertSnapshotUpdated, .alertsChanged:
            return includeAlertEvents
        case .connectionSnapshotUpdated, .bluetoothStateChanged, .connectionServiceError:
            return includeConnectionEvents
        }
    }
}

enum RuuviTagCoordinatorEventType: String, CaseIterable {
    // Data Service Events
    case snapshotsUpdated
    case snapshotUpdated
    case newSensorAdded
    case dataServiceError

    // Cloud Service Events
    case userLoginStateChanged
    case userLogoutStateChanged
    case cloudSyncStatusChanged
    case cloudSyncCompleted
    case historySyncInProgress
    case authorizationFailed
    case cloudModeChanged

    // Alert Service Events
    case alertSnapshotUpdated
    case alertsChanged

    // Connection Service Events
    case connectionSnapshotUpdated
    case bluetoothStateChanged
    case connectionServiceError
}

extension RuuviTagServiceCoordinatorEvent {
    var eventType: RuuviTagCoordinatorEventType {
        switch self {
        case .snapshotsUpdated:
            return .snapshotsUpdated
        case .snapshotUpdated:
            return .snapshotUpdated
        case .newSensorAdded:
            return .newSensorAdded
        case .dataServiceError:
            return .dataServiceError
        case .userLoginStateChanged:
            return .userLoginStateChanged
        case .userLogoutStateChanged:
            return .userLogoutStateChanged
        case .cloudSyncStatusChanged:
            return .cloudSyncStatusChanged
        case .cloudSyncCompleted:
            return .cloudSyncCompleted
        case .historySyncInProgress:
            return .historySyncInProgress
        case .authorizationFailed:
            return .authorizationFailed
        case .cloudModeChanged:
            return .cloudModeChanged
        case .alertSnapshotUpdated:
            return .alertSnapshotUpdated
        case .alertsChanged:
            return .alertsChanged
        case .connectionSnapshotUpdated:
            return .connectionSnapshotUpdated
        case .bluetoothStateChanged:
            return .bluetoothStateChanged
        case .connectionServiceError:
            return .connectionServiceError
        }
    }
}
// swiftlint:enable file_length
