// swiftlint:disable file_length

import Foundation
import RuuviOntology
import RuuviService
import RuuviNotifier
import RuuviLocal

protocol RuuviTagAlertServiceDelegate: AnyObject {
    func alertService(
        _ service: RuuviTagAlertService,
        didUpdateSnapshot snapshot: RuuviTagCardSnapshot
    )
    func alertService(
        _ service: RuuviTagAlertService,
        alertsDidChange: Bool
    )
}

class RuuviTagAlertService {

    // MARK: - Dependencies
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let settings: RuuviLocalSettings

    // MARK: - Properties
    weak var delegate: RuuviTagAlertServiceDelegate?

    // MARK: - Observation Tokens
    private var alertDidChangeToken: NSObjectProtocol?

    // MARK: - CPU Optimization: Maintain Snapshot References
    private var snapshots: [String: RuuviTagCardSnapshot] = [:]
    private let snapshotsQueue = DispatchQueue(label: "com.ruuvi.snapshots", attributes: .concurrent)

    // MARK: - CPU Optimization: Debouncing
    private var pendingUpdates: Set<String> = []
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.1 // 100ms debounce

    // MARK: - CPU Optimization: Alert Caching
    private var alertStateCache: [String: [AlertType: (isOn: Bool, mutedTill: Date?)]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.ruuvi.alertCache", attributes: .concurrent)

    // MARK: - CPU Optimization: Single Background Queue
    private let processingQueue = DispatchQueue(label: "com.ruuvi.alertProcessing", qos: .utility)

    // MARK: - CPU Optimization: Prevent Loops
    private var isProcessingAlertChange = false
    private let processingLock = NSLock()

    // MARK: - Initialization
    init(
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier,
        settings: RuuviLocalSettings
    ) {
        self.alertService = alertService
        self.alertHandler = alertHandler
        self.settings = settings
    }

    deinit {
        stopObservingAlerts()
        debounceTimer?.invalidate()
        clearCache()
    }

    // MARK: - Public Interface
    func startObservingAlerts() {
        observeAlertChanges()
    }

    func stopObservingAlerts() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = nil
        debounceTimer?.invalidate()
    }

    // MARK: - Snapshot Management
    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot) {
        snapshotsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.snapshots[snapshot.id] = snapshot
        }
    }

    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        snapshotsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.snapshots.removeAll()
            for snapshot in snapshots {
                self.snapshots[snapshot.id] = snapshot
            }
        }
    }

    // MARK: - Alert Subscription Management
    func subscribeToAlerts(for snapshots: [RuuviTagCardSnapshot]) {
        updateSnapshots(snapshots)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            for snapshot in snapshots {
                if snapshot.metadata.isCloud {
                    if let macId = snapshot.identifierData.mac?.value {
                        self.alertHandler.subscribe(self, to: macId)
                    }
                } else {
                    if let luid = snapshot.identifierData.luid?.value {
                        self.alertHandler.subscribe(self, to: luid)
                    } else if let macId = snapshot.identifierData.mac?.value {
                        self.alertHandler.subscribe(self, to: macId)
                    }
                }
            }
        }
    }

    // MARK: - Alert Syncing
    func syncAllAlerts(for snapshot: RuuviTagCardSnapshot, physicalSensor: PhysicalSensor) {
        updateSnapshot(snapshot)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            if self.settings.isSyncing {
                // Just update the cache without full processing when a sync is going on.
                self.cacheAlertStatesForSnapshot(snapshot, physicalSensor: physicalSensor)
                return
            }

            // Prevent recursive calls
            self.processingLock.lock()
            guard !self.isProcessingAlertChange else {
                self.processingLock.unlock()
                return
            }
            self.isProcessingAlertChange = true
            self.processingLock.unlock()

            // Clear cache for this sensor to force refresh
            self.clearCacheForSensor(sensorId: physicalSensor.id)

            // Sync alerts using the optimized snapshot method
            snapshot.syncAllAlerts(from: self.alertService, physicalSensor: physicalSensor)

            // Cache the alert states after sync
            self.cacheAlertStatesForSnapshot(snapshot, physicalSensor: physicalSensor)

            // Reset processing flag
            self.processingLock.lock()
            self.isProcessingAlertChange = false
            self.processingLock.unlock()

            // Notify on main thread
            DispatchQueue.main.async {
                self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
            }
        }
    }

    // MARK: - Alert Processing
    func processAlert(record: RuuviTagSensorRecord, snapshot: RuuviTagCardSnapshot) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            if snapshot.metadata.isCloud {
                if let macId = snapshot.identifierData.mac {
                    self.alertHandler.processNetwork(record: record, trigger: false, for: macId)
                }
            } else {
                if snapshot.identifierData.luid != nil {
                    self.alertHandler.process(record: record, trigger: false)
                } else if let macId = snapshot.identifierData.mac {
                    self.alertHandler.processNetwork(record: record, trigger: false, for: macId)
                }
            }
        }
    }

    func triggerAlertsIfNeeded(for snapshots: [RuuviTagCardSnapshot]) {
        updateSnapshots(snapshots)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            for snapshot in snapshots {
                if let lastRecord = snapshot.latestRawRecord {
                    if snapshot.metadata.isCloud {
                        if let macId = snapshot.identifierData.mac {
                            self.alertHandler.processNetwork(record: lastRecord, trigger: false, for: macId)
                        }
                    } else {
                        if snapshot.identifierData.luid != nil {
                            self.alertHandler.process(record: lastRecord, trigger: false)
                        } else if let macId = snapshot.identifierData.mac {
                            self.alertHandler.processNetwork(record: lastRecord, trigger: false, for: macId)
                        }
                    }
                }
            }
        }
    }

    func triggerAlertsIfNeeded(for snapshot: RuuviTagCardSnapshot) {
        updateSnapshot(snapshot)

        processingQueue.async { [weak self] in
            guard let self = self else { return }

            if let lastRecord = snapshot.latestRawRecord {
                if snapshot.metadata.isCloud {
                    if let macId = snapshot.identifierData.mac {
                        self.alertHandler.processNetwork(record: lastRecord, trigger: false, for: macId)
                    }
                } else {
                    if snapshot.identifierData.luid != nil {
                        self.alertHandler.process(record: lastRecord, trigger: false)
                    } else if let macId = snapshot.identifierData.mac {
                        self.alertHandler.processNetwork(record: lastRecord, trigger: false, for: macId)
                    }
                }
            }
        }
    }

    // MARK: - Alert State Updates
    func updateAlertForMeasurement(
        snapshot: RuuviTagCardSnapshot,
        type: MeasurementType,
        isOn: Bool,
        alertState: AlertState?,
        mutedTill: Date?
    ) {
        // Update cache and snapshot (uses optimized change detection)
        let alertType = type.toAlertType()
        setCachedAlertState(for: snapshot.id, alertType: alertType, isOn: isOn, mutedTill: mutedTill)

        snapshot.updateAlert(
            for: type,
            isOn: isOn,
            alertState: alertState,
            mutedTill: mutedTill
        )

        // Debounce delegate notifications to prevent CPU spinning
        addToPendingUpdates(snapshotId: snapshot.id)
    }
}

// MARK: - CPU Optimization: Debouncing
private extension RuuviTagAlertService {

    func addToPendingUpdates(snapshotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.pendingUpdates.insert(snapshotId)

            // Cancel previous timer
            self.debounceTimer?.invalidate()

            // Start new debounce timer
            self.debounceTimer = Timer.scheduledTimer(withTimeInterval: self.debounceInterval, repeats: false) { _ in
                self.processPendingUpdates()
            }
        }
    }

    func processPendingUpdates() {
        let updatedSnapshotIds = Array(pendingUpdates)
        pendingUpdates.removeAll()

        snapshotsQueue.sync { [weak self] in
            guard let self = self else { return }

            for snapshotId in updatedSnapshotIds {
                if let snapshot = self.snapshots[snapshotId] {
                    DispatchQueue.main.async {
                        self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
                    }
                }
            }
        }

        // Single batch notification
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.alertService(self, alertsDidChange: true)
        }
    }
}

// MARK: - Private Implementation
private extension RuuviTagAlertService {

    func observeAlertChanges() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = NotificationCenter.default.addObserver(
            forName: .RuuviServiceAlertDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            guard !self.settings.isSyncing else { return }

            // Prevent notification loops
            self.processingLock.lock()
            guard !self.isProcessingAlertChange else {
                self.processingLock.unlock()
                return
            }
            self.processingLock.unlock()

            if let userInfo = notification.userInfo,
               let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
               let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {

                // Clear cache immediately
                self.clearCachedAlertState(for: physicalSensor.id, alertType: type)

                // Find snapshot without blocking threads
                self.snapshotsQueue.sync { [weak self] in
                    guard let self = self,
                          let snapshot = self.snapshots[physicalSensor.id] else { return }

                    // Process on background thread
                    self.processingQueue.async {
                        self.updateAlertStateForSnapshot(
                            snapshot: snapshot,
                            alertType: type,
                            physicalSensor: physicalSensor
                        )
                    }
                }
            }
        }
    }

    func updateAlertStateForSnapshot(
        snapshot: RuuviTagCardSnapshot,
        alertType: AlertType,
        physicalSensor: PhysicalSensor
    ) {
        guard let measurementType = alertType.toMeasurementType() else { return }

        // Try cache first
        if let cached = getCachedAlertState(for: physicalSensor.id, alertType: alertType) {
            let alertState: AlertState? = cached.isOn ? .registered : nil
            snapshot.updateAlert(
                for: measurementType,
                isOn: cached.isOn,
                alertState: alertState,
                mutedTill: cached.mutedTill
            )

            // Use debounced update
            addToPendingUpdates(snapshotId: snapshot.id)
            return
        }

        // Fetch alert state (we're on background thread)
        let isOn = alertService.isOn(type: alertType, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

        // Cache result
        setCachedAlertState(for: physicalSensor.id, alertType: alertType, isOn: isOn, mutedTill: mutedTill)

        var alertState: AlertState?
        if let alertConfig = snapshot.displayData.indicatorGrid?.indicators.first(
            where: {
                $0.type == measurementType
            }
        )?.alertConfig {
            if isOn {
                if alertConfig.isFiring {
                    alertState = .firing
                } else {
                    alertState = .registered
                }
            } else {
                alertState = .empty
            }
        }
        snapshot.updateAlert(
            for: measurementType,
            isOn: isOn,
            alertState: alertState,
            mutedTill: mutedTill
        )

        // Use debounced update
        addToPendingUpdates(snapshotId: snapshot.id)
    }
}

// MARK: - Alert Cache Management
private extension RuuviTagAlertService {

    func getCachedAlertState(for sensorId: String, alertType: AlertType) -> (isOn: Bool, mutedTill: Date?)? {
        return cacheQueue.sync {
            return alertStateCache[sensorId]?[alertType]
        }
    }

    func setCachedAlertState(
        for sensorId: String,
        alertType: AlertType,
        isOn: Bool,
        mutedTill: Date?
    ) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            if self?.alertStateCache[sensorId] == nil {
                self?.alertStateCache[sensorId] = [:]
            }
            self?.alertStateCache[sensorId]?[alertType] = (isOn: isOn, mutedTill: mutedTill)
        }
    }

    func clearCachedAlertState(for sensorId: String, alertType: AlertType) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.alertStateCache[sensorId]?[alertType] = nil
        }
    }

    func clearCacheForSensor(sensorId: String) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.alertStateCache[sensorId] = nil
        }
    }

    func clearCache() {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.alertStateCache.removeAll()
        }
    }

    func cacheAlertStatesForSnapshot(
        _ snapshot: RuuviTagCardSnapshot,
        physicalSensor: PhysicalSensor
    ) {
        guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { return }

        for indicator in indicators {
            let alertType = indicator.type.toAlertType()
            let isOn = indicator.alertConfig.isActive
            let mutedTill = indicator.alertConfig.mutedTill

            setCachedAlertState(
                for: physicalSensor.id,
                alertType: alertType,
                isOn: isOn,
                mutedTill: mutedTill
            )
        }
    }
}

// MARK: - RuuviNotifierObserver - Optimized
extension RuuviTagAlertService: RuuviNotifierObserver {

    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        addToPendingUpdates(snapshotId: uuid)
    }

    func ruuvi(
        notifier: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        // Find snapshot and update alert state
        snapshotsQueue.sync { [weak self] in
            guard let self = self,
                  let snapshot = self.findSnapshotByIdentifier(uuid) else { return }

            // Process on background thread with loop protection
            self.processingQueue.async {
                self.processingLock.lock()
                guard !self.isProcessingAlertChange else {
                    self.processingLock.unlock()
                    return
                }
                self.isProcessingAlertChange = true
                self.processingLock.unlock()

                // Update alert state for specific alert type
                guard let measurementType = alertType.toMeasurementType() else {
                    self.processingLock.lock()
                    self.isProcessingAlertChange = false
                    self.processingLock.unlock()
                    return
                }

                // Determine if alert should be fireable based on connection status
                let isFireable = snapshot.metadata.isCloud ||
                                snapshot.connectionData.isConnected ||
                                snapshot.identifierData.serviceUUID != nil

                let isTriggeredAndFireable = isTriggered && isFireable
                let alertState: AlertState? = isTriggeredAndFireable ? .firing : .registered
                snapshot.updateAlert(
                    for: measurementType,
                    isOn: self.alertService.isOn(type: alertType, for: uuid),
                    alertState: alertState,
                    mutedTill: self.alertService.mutedTill(type: alertType, for: uuid)
                )

                self.processingLock.lock()
                self.isProcessingAlertChange = false
                self.processingLock.unlock()

                // Use debounced update
                self.addToPendingUpdates(snapshotId: snapshot.id)
            }
        }
    }

    private func findSnapshotByIdentifier(_ identifier: String) -> RuuviTagCardSnapshot? {
        // Try direct ID match first
        if let snapshot = snapshots[identifier] {
            return snapshot
        }

        // Try LUID/MAC match
        return snapshots.values.first { snapshot in
            snapshot.identifierData.luid?.value == identifier ||
            snapshot.identifierData.mac?.value == identifier
        }
    }
}

// MARK: - Alert Processing Helpers
extension RuuviTagAlertService {

    func hasActiveAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { return false }
        return indicators.contains { $0.alertConfig.isActive }
    }

    func hasFiringAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { return false }
        return indicators.contains { $0.alertConfig.isFiring }
    }

    // MARK: - Muted Till Management
    func reloadMutedTillStates(for snapshots: [RuuviTagCardSnapshot]) {
        let currentDate = Date()

        for snapshot in snapshots {
            guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { continue }

            var hasChanges = false
            let updatedIndicators = indicators.map { indicator -> RuuviTagCardSnapshotIndicatorData in
                if let mutedTill = indicator.alertConfig.mutedTill, mutedTill < currentDate {
                    hasChanges = true
                    return RuuviTagCardSnapshotIndicatorData(
                        type: indicator.type,
                        value: indicator.value,
                        unit: indicator.unit,
                        alertConfig: RuuviTagCardSnapshotAlertConfig(
                            isActive: indicator.alertConfig.isActive,
                            isFiring: indicator.alertConfig.isFiring,
                            mutedTill: nil // Clear expired muted state
                        ),
                        isProminent: indicator.isProminent,
                        showSubscript: indicator.showSubscript,
                        tintColor: indicator.tintColor
                    )
                } else {
                    return indicator
                }
            }

            if hasChanges {
                snapshot.displayData.indicatorGrid = RuuviTagCardSnapshotIndicatorGridConfiguration(
                    indicators: updatedIndicators
                )
                addToPendingUpdates(snapshotId: snapshot.id)
            }
        }
    }
}

// swiftlint:enable file_length
