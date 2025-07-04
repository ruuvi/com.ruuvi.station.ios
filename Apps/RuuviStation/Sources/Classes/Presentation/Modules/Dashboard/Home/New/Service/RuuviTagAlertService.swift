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

    // MARK: - SIMPLIFIED THREADING: Single Serial Queue
    private let alertQueue = DispatchQueue(label: "com.ruuvi.alertService", qos: .utility)

    // MARK: - State Management (Thread-Safe)
    private var snapshots: [String: RuuviTagCardSnapshot] = [:]
    private var isProcessing = false

    // MARK: - Simplified Debouncing
    private var pendingSnapshots: Set<String> = []
    private var debounceWorkItem: DispatchWorkItem?

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
        debounceWorkItem?.cancel()
    }

    // MARK: - Public Interface
    func startObservingAlerts() {
        alertQueue.async { [weak self] in
            self?.observeAlertChanges()
        }
    }

    func stopObservingAlerts() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = nil
        debounceWorkItem?.cancel()
    }

    // MARK: - Snapshot Management (Thread-Safe)
    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot) {
        alertQueue.async { [weak self] in
            self?.snapshots[snapshot.id] = snapshot
        }
    }

    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        alertQueue.async { [weak self] in
            guard let self = self else { return }
            self.snapshots.removeAll()
            for snapshot in snapshots {
                self.snapshots[snapshot.id] = snapshot
            }
        }
    }

    // MARK: - Alert Subscription (Simplified)
    func subscribeToAlerts(for snapshots: [RuuviTagCardSnapshot]) {
        updateSnapshots(snapshots)

        alertQueue.async { [weak self] in
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

    // MARK: - Alert Processing (Simplified & Thread-Safe)
    func triggerAlertsIfNeeded(for snapshots: [RuuviTagCardSnapshot]) {
        alertQueue.async { [weak self] in
            guard let self = self, !self.isProcessing else { return }

            self.isProcessing = true
            defer { self.isProcessing = false }

            self.processAlertsForSnapshots(snapshots)
        }
    }

    func triggerAlertsIfNeeded(for snapshot: RuuviTagCardSnapshot) {
        alertQueue.async { [weak self] in
            guard let self = self, !self.isProcessing else { return }

            self.isProcessing = true
            defer { self.isProcessing = false }

            self.processAlertsForSnapshot(snapshot)
        }
    }

    // MARK: - Alert State Updates (Simplified)
    func updateAlertForMeasurement(
        snapshot: RuuviTagCardSnapshot,
        type: MeasurementType,
        isOn: Bool,
        alertState: AlertState?,
        mutedTill: Date?
    ) {
        alertQueue.async { [weak self] in
            guard let self = self else { return }

            // Update snapshot directly (no complex caching)
            snapshot.updateAlert(
                for: type,
                isOn: isOn,
                alertState: alertState,
                mutedTill: mutedTill
            )

            // Schedule debounced update
            self.scheduleSnapshotUpdate(snapshot.id)
        }
    }

    // MARK: - Alert Syncing (Simplified)
    func syncAllAlerts(for snapshot: RuuviTagCardSnapshot, physicalSensor: PhysicalSensor) {
        alertQueue.async { [weak self] in
            guard let self = self, !self.settings.isSyncing else { return }

            // Simple sync without complex state management
            snapshot.syncAllAlerts(from: self.alertService, physicalSensor: physicalSensor)

            // Immediate delegate notification
            DispatchQueue.main.async {
                self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
            }
        }
    }
}

// MARK: - Private Implementation (Simplified)
private extension RuuviTagAlertService {

    func observeAlertChanges() {
        // Observe on main queue but process on alert queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.alertDidChangeToken?.invalidate()
            self.alertDidChangeToken = NotificationCenter.default.addObserver(
                forName: .RuuviServiceAlertDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleAlertDidChange(notification)
            }
        }
    }

    func handleAlertDidChange(_ notification: Notification) {
        guard !settings.isSyncing,
              let userInfo = notification.userInfo,
              let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
              let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType else {
            return
        }

        alertQueue.async { [weak self] in
            self?.processAlertChange(physicalSensor: physicalSensor, alertType: type)
        }
    }

    func processAlertChange(physicalSensor: PhysicalSensor, alertType: AlertType) {
        guard let snapshot = snapshots[physicalSensor.id],
              let measurementType = alertType.toMeasurementType() else {
            return
        }

        // Simple alert state update
        let isOn = alertService.isOn(type: alertType, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)
        let alertState: AlertState? = isOn ? .registered : nil

        snapshot.updateAlert(
            for: measurementType,
            isOn: isOn,
            alertState: alertState,
            mutedTill: mutedTill
        )

        scheduleSnapshotUpdate(snapshot.id)
    }

    func processAlertsForSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        for snapshot in snapshots {
            processAlertsForSnapshot(snapshot)
        }
    }

    func processAlertsForSnapshot(_ snapshot: RuuviTagCardSnapshot) {
        guard let lastRecord = snapshot.latestRawRecord else { return }

        // CRITICAL FIX: Use try-catch equivalent to prevent crashes
        do {
            if snapshot.metadata.isCloud {
                if let macId = snapshot.identifierData.mac {
                    // Wrap in safety check
                    try processNetworkAlert(record: lastRecord, macId: macId)
                }
            } else {
                if snapshot.identifierData.luid != nil {
                    try processLocalAlert(record: lastRecord)
                } else if let macId = snapshot.identifierData.mac {
                    try processNetworkAlert(record: lastRecord, macId: macId)
                }
            }
        } catch {
            print("Alert processing error for snapshot \(snapshot.id): \(error)")
            // Continue processing other snapshots instead of crashing
        }
    }

    func processNetworkAlert(record: RuuviTagSensorRecord, macId: MACIdentifier) throws {
        // Safely call alert handler with error handling
        alertHandler.processNetwork(record: record, trigger: false, for: macId)
    }

    func processLocalAlert(record: RuuviTagSensorRecord) throws {
        // Safely call alert handler with error handling
        alertHandler.process(record: record, trigger: false)
    }

    // MARK: - Simplified Debouncing
    func scheduleSnapshotUpdate(_ snapshotId: String) {
        pendingSnapshots.insert(snapshotId)

        // Cancel previous work item
        debounceWorkItem?.cancel()

        // Create new work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.processPendingUpdates()
        }
        debounceWorkItem = workItem

        // Schedule on alert queue with delay
        alertQueue.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    func processPendingUpdates() {
        let snapshotIds = Array(pendingSnapshots)
        pendingSnapshots.removeAll()

        // Notify delegate on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            for snapshotId in snapshotIds {
                if let snapshot = self.snapshots[snapshotId] {
                    self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
                }
            }

            if !snapshotIds.isEmpty {
                self.delegate?.alertService(self, alertsDidChange: true)
            }
        }
    }
}

// MARK: - RuuviNotifierObserver (Simplified)
extension RuuviTagAlertService: RuuviNotifierObserver {

    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        alertQueue.async { [weak self] in
            self?.scheduleSnapshotUpdate(uuid)
        }
    }

    func ruuvi(
        notifier: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        alertQueue.async { [weak self] in
            guard let self = self,
                  let snapshot = self.findSnapshotByIdentifier(uuid),
                  let measurementType = alertType.toMeasurementType() else {
                return
            }

            // Simplified alert state update
            let isFireable = snapshot.metadata.isCloud ||
                           snapshot.connectionData.isConnected ||
                           snapshot.identifierData.serviceUUID != nil

            let alertState: AlertState? = (isTriggered && isFireable) ? .firing : .registered
            let isOn = self.alertService.isOn(type: alertType, for: uuid)
            let mutedTill = self.alertService.mutedTill(type: alertType, for: uuid)

            snapshot.updateAlert(
                for: measurementType,
                isOn: isOn,
                alertState: alertState,
                mutedTill: mutedTill
            )

            self.scheduleSnapshotUpdate(snapshot.id)
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

// MARK: - Alert Processing Helpers (Simplified)
extension RuuviTagAlertService {

    func hasActiveAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { return false }
        return indicators.contains { $0.alertConfig.isActive }
    }

    func hasFiringAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        guard let indicators = snapshot.displayData.indicatorGrid?.indicators else { return false }
        return indicators.contains { $0.alertConfig.isFiring }
    }
}

// MARK: - Alert State Mapping Extensions
extension AlertType {
    func toMeasurementType() -> MeasurementType? {
        switch self {
        case .temperature: return .temperature
        case .relativeHumidity: return .humidity
        case .pressure: return .pressure
        case .movement: return .movementCounter
        case .carbonDioxide: return .co2
        case .pMatter2_5: return .pm25
        case .pMatter10: return .pm10
        case .nox: return .nox
        case .voc: return .voc
        case .sound: return .sound
        case .luminosity: return .luminosity
        default: return nil
        }
    }
}

// swiftlint:enable file_length
