// swiftlint:disable file_length

import Foundation
import UIKit
import RuuviOntology
import RuuviService
import RuuviNotifier
import RuuviLocal
import RuuviCore

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

// swiftlint:disable:next type_body_length
class RuuviTagAlertService {

    // MARK: - Dependencies
    private let alertService: RuuviServiceAlert
    private let alertHandler: RuuviNotifier
    private let settings: RuuviLocalSettings
    private let pushNotificationsManager: RuuviCorePN

    // MARK: - Properties
    weak var delegate: RuuviTagAlertServiceDelegate?

    // MARK: - Observation Tokens
    private var alertDidChangeToken: NSObjectProtocol?

    // MARK: - Snapshot Management
    private var snapshots: [String: RuuviTagCardSnapshot] = [:]
    private let snapshotsQueue = DispatchQueue(label: "com.ruuvi.snapshots", attributes: .concurrent)

    // MARK: - Debouncing
    private var pendingUpdates: Set<String> = []
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.1
    private let lowUpperDebounceDelay: TimeInterval = 0.3

    // MARK: - Background Processing
    private let backgroundQueue = DispatchQueue(label: "com.ruuvi.alertBackground", qos: .utility)

    // MARK: - Loop Prevention
    private var isProcessingAlertChange = false
    private let processingLock = NSLock()

    // MARK: - Debouncing Management
    private var debouncers: [String: Debouncer] = [:]

    // MARK: - Push Notifications State
    private var pushNotificationsEnabled = false
    private var pushNotificationStatusLoaded = false
    private var appStateObserver: NSObjectProtocol?
    private var muteRefreshTimer: Timer?
    private let muteRefreshInterval: TimeInterval = 5
    private var muteRefreshActive = false

    // MARK: - Initialization
    init(
        alertService: RuuviServiceAlert,
        alertHandler: RuuviNotifier,
        settings: RuuviLocalSettings,
        pushNotificationsManager: RuuviCorePN
    ) {
        self.alertService = alertService
        self.alertHandler = alertHandler
        self.settings = settings
        self.pushNotificationsManager = pushNotificationsManager

        refreshPushNotificationStatus()
        appStateObserver = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshPushNotificationStatus()
            }
    }

    deinit {
        stopObservingAlerts()
        debounceTimer?.invalidate()
        debouncers.values.forEach { $0.cancel() }
        muteRefreshTimer?.invalidate()
        if let appStateObserver {
            NotificationCenter.default.removeObserver(appStateObserver)
        }
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
            self.schedulePushCapabilityUpdate(for: snapshot)
            self.ensureMutedTillRefreshTimer()
        }
    }

    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        snapshotsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.snapshots.removeAll()
            for snapshot in snapshots {
                self.snapshots[snapshot.id] = snapshot
            }
            self.schedulePushCapabilityUpdate(for: snapshots)
            if snapshots.isEmpty {
                self.stopMutedTillRefreshTimer()
            } else {
                self.ensureMutedTillRefreshTimer()
            }
        }
    }

    func disableHiddenMeasurementAlerts(
        for snapshots: [RuuviTagCardSnapshot],
        sensors: [AnyRuuviTagSensor]
    ) {
        let sensorMap = sensors.reduce(into: [String: AnyRuuviTagSensor]()) { partial, sensor in
            partial[sensor.id] = sensor
        }

        for snapshot in snapshots {
            guard let sensor = sensorMap[snapshot.id] else { continue }
            disableHiddenMeasurementAlerts(for: snapshot, sensor: sensor)
        }
    }

    private func disableHiddenMeasurementAlerts(
        for snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor
    ) {
        // Run this call only for shared sensors. We do migration for owner in
        // MigrationManagerSignalVisibility for Signal alert.
        guard !sensor.isOwner else { return }

        let visibility = snapshot.displayData.measurementVisibility
        let displayProfile: MeasurementDisplayProfile = {
            if let visibility, visibility.usesDefaultOrder {
                return RuuviTagDataService.defaultMeasurementDisplayProfile(for: sensor)
            }
            if visibility == nil {
                return RuuviTagDataService.defaultMeasurementDisplayProfile(for: sensor)
            }
            return RuuviTagDataService.measurementDisplayProfile(for: sensor)
        }()

        let visibleTypes = visibility?.visibleVariants.map(\.type)
            ?? displayProfile.orderedVisibleVariants(for: .indicator).map(\.type)

        var enabledMeasurementAlerts: [(alert: AlertType, measurement: MeasurementType)] = []
        for candidate in AlertType.allCases {
            guard let measurementType = candidate.toMeasurementType() else { continue }
            if alertService.isOn(type: candidate, for: sensor) {
                enabledMeasurementAlerts.append((candidate, measurementType))
            }
        }

        for enabled in enabledMeasurementAlerts {
            let type = enabled.measurement
            guard !visibleTypes.contains(where: { $0.isSameCase(as: type) }) else { continue }

            let activeAlert = alertService.alert(for: sensor, of: enabled.alert) ?? enabled.alert
            DispatchQueue.main.async { [weak self] in
                self?.setAlertState(
                    for: activeAlert,
                    isOn: false,
                    snapshot: snapshot,
                    physicalSensor: sensor
                )
            }
        }
    }

    // MARK: - Alert Subscription Management
    func subscribeToAlerts(for snapshots: [RuuviTagCardSnapshot]) {
        updateSnapshots(snapshots)

        DispatchQueue.main.async { [weak self] in
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

        if settings.isSyncing {
            return
        }

        processingLock.lock()
        guard !isProcessingAlertChange else {
            processingLock.unlock()
            return
        }
        isProcessingAlertChange = true
        processingLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Sync all measurement-based alerts
            let profile = RuuviTagDataService.measurementDisplayProfile(for: snapshot)
            let measurementTypes = profile.entries(for: .alert).map(\.type)

            for measurementType in measurementTypes {
                self.syncMeasurementAlert(
                    type: measurementType,
                    snapshot: snapshot,
                    physicalSensor: physicalSensor
                )
            }

            // Sync non-measurement alerts
            let nonMeasurementAlertTypes: [AlertType] = [
                .connection,
                .cloudConnection(
                    unseenDuration: 0
                ),
                .movement(
                    last: 0
                ),
            ]
            for alertType in nonMeasurementAlertTypes {
                self.syncNonMeasurementAlert(
                    type: alertType,
                    snapshot: snapshot,
                    physicalSensor: physicalSensor
                )
            }

            self.processingLock.lock()
            self.isProcessingAlertChange = false
            self.processingLock.unlock()

            self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
        }
    }

    // MARK: - Alert State Management
    func setAlertState(
        for alertType: AlertType,
        isOn: Bool,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: RuuviTagSensor
    ) {
        let currentConfig = snapshot.getAlertConfig(for: alertType) ?? createDefaultConfig(for: alertType)
        let alertTypeWithBounds = createAlertTypeWithBounds(alertType, config: currentConfig)

        let currentState = alertService.isOn(type: alertTypeWithBounds, for: physicalSensor)

        if currentState != isOn {
            if isOn {
                alertService.register(type: alertTypeWithBounds, ruuviTag: physicalSensor)
            } else {
                alertService.unregister(type: alertTypeWithBounds, ruuviTag: physicalSensor)
            }
            alertService.unmute(type: alertTypeWithBounds, for: physicalSensor)

            // Update snapshot
            let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                type: currentConfig.type,
                alertType: alertType,
                isActive: isOn,
                isFiring: currentConfig.isFiring,
                mutedTill: nil,
                lowerBound: currentConfig.lowerBound,
                upperBound: currentConfig.upperBound,
                description: currentConfig.description,
                unseenDuration: currentConfig.unseenDuration
            )

            snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
            processAlerts(for: snapshot)
            addToPendingUpdates(snapshotId: snapshot.id)
        }
    }

    func setAlertBounds(
        for alertType: AlertType,
        lowerBound: Double? = nil,
        upperBound: Double? = nil,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: RuuviTagSensor
    ) {
        let currentConfig = snapshot.getAlertConfig(for: alertType) ?? createDefaultConfig(for: alertType)

        var updatedConfig = currentConfig
        if let lowerBound = lowerBound {
            updatedConfig = RuuviTagCardSnapshotAlertConfig(
                type: currentConfig.type,
                alertType: currentConfig.alertType,
                isActive: currentConfig.isActive,
                isFiring: currentConfig.isFiring,
                mutedTill: currentConfig.mutedTill,
                lowerBound: lowerBound,
                upperBound: currentConfig.upperBound,
                description: currentConfig.description,
                unseenDuration: currentConfig.unseenDuration
            )

            let debouncer = getDebouncerForKey("\(alertType)_lower_\(snapshot.id)")
            debouncer.run { [weak self] in
                self?.setLowerBoundInService(type: alertType, value: lowerBound, physicalSensor: physicalSensor)
                self?.processAlerts(for: snapshot)
            }
        }

        if let upperBound = upperBound {
            updatedConfig = RuuviTagCardSnapshotAlertConfig(
                type: updatedConfig.type,
                alertType: updatedConfig.alertType,
                isActive: updatedConfig.isActive,
                isFiring: updatedConfig.isFiring,
                mutedTill: updatedConfig.mutedTill,
                lowerBound: updatedConfig.lowerBound,
                upperBound: upperBound,
                description: updatedConfig.description,
                unseenDuration: updatedConfig.unseenDuration
            )

            let debouncer = getDebouncerForKey("\(alertType)_upper_\(snapshot.id)")
            debouncer.run { [weak self] in
                self?.setUpperBoundInService(type: alertType, value: upperBound, physicalSensor: physicalSensor)
                self?.processAlerts(for: snapshot)
            }
        }

        snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
        addToPendingUpdates(snapshotId: snapshot.id)
    }

    func setAlertDescription(
        for alertType: AlertType,
        description: String?,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: RuuviTagSensor
    ) {
        setDescriptionInService(
            type: alertType,
            description: description,
            physicalSensor: physicalSensor
        )

        let currentConfig = snapshot.getAlertConfig(for: alertType) ?? createDefaultConfig(for: alertType)
        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: currentConfig.mutedTill,
            lowerBound: currentConfig.lowerBound,
            upperBound: currentConfig.upperBound,
            description: description,
            unseenDuration: currentConfig.unseenDuration
        )

        snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
        addToPendingUpdates(snapshotId: snapshot.id)
    }

    func setCloudConnectionUnseenDuration(
        _ duration: Double,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: RuuviTagSensor
    ) {
        let alertType: AlertType = .cloudConnection(unseenDuration: 0)
        let currentConfig = snapshot.getAlertConfig(for: alertType) ??
            createDefaultConfig(for: alertType)

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: currentConfig.mutedTill,
            lowerBound: currentConfig.lowerBound,
            upperBound: currentConfig.upperBound,
            description: currentConfig.description,
            unseenDuration: duration
        )

        snapshot.updateAlertConfig(for: alertType, config: updatedConfig)

        let debouncer = getDebouncerForKey("cloudConnection_unseen_\(snapshot.id)")
        debouncer.run { [weak self] in
            guard let self else { return }
            self.alertService.setCloudConnection(
                unseenDuration: duration,
                ruuviTag: physicalSensor
            )
            self.processAlerts(for: snapshot)
        }

        addToPendingUpdates(snapshotId: snapshot.id)
    }

    // MARK: - Alert Processing
    func processAlert(record: RuuviTagSensorRecord, snapshot: RuuviTagCardSnapshot) {
        DispatchQueue.main.async { [weak self] in
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

    private func processAlerts(for snapshot: RuuviTagCardSnapshot) {
        guard let lastRecord = snapshot.latestRawRecord else { return }
        processAlert(record: lastRecord, snapshot: snapshot)
    }

    func triggerAlertsIfNeeded(for snapshots: [RuuviTagCardSnapshot]) {
        updateSnapshots(snapshots)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reloadMutedTillStates(for: snapshots)
            snapshots.forEach { self.processAlerts(for: $0) }
        }
    }

    func triggerAlertsIfNeeded(for snapshot: RuuviTagCardSnapshot) {
        updateSnapshot(snapshot)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reloadMutedTillStates(for: [snapshot])
            self.processAlerts(for: snapshot)
        }
    }

    // MARK: - Mute/Unmute Alert
    func muteAlert(
        for alertType: AlertType,
        till: Date,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: PhysicalSensor
    ) {
        alertService.mute(type: alertType, for: physicalSensor, till: till)

        if let currentConfig = snapshot.getAlertConfig(for: alertType) {
            let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                type: currentConfig.type,
                alertType: currentConfig.alertType,
                isActive: currentConfig.isActive,
                isFiring: currentConfig.isFiring,
                mutedTill: till,
                lowerBound: currentConfig.lowerBound,
                upperBound: currentConfig.upperBound,
                description: currentConfig.description,
                unseenDuration: currentConfig.unseenDuration
            )
            snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
        }

        addToPendingUpdates(snapshotId: snapshot.id)
    }

    func unmuteAlert(
        for alertType: AlertType,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: PhysicalSensor
    ) {
        alertService.unmute(type: alertType, for: physicalSensor)

        if let currentConfig = snapshot.getAlertConfig(for: alertType) {
            let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                type: currentConfig.type,
                alertType: currentConfig.alertType,
                isActive: currentConfig.isActive,
                isFiring: currentConfig.isFiring,
                mutedTill: nil,
                lowerBound: currentConfig.lowerBound,
                upperBound: currentConfig.upperBound,
                description: currentConfig.description,
                unseenDuration: currentConfig.unseenDuration
            )
            snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
        }

        addToPendingUpdates(snapshotId: snapshot.id)
    }

    func setMuteRefreshActive(_ active: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.muteRefreshActive == active { return }
            self.muteRefreshActive = active
            if active {
                self.ensureMutedTillRefreshTimer()
            } else {
                self.stopMutedTillRefreshTimer()
            }
        }
    }

    // MARK: - Helper Methods
    func hasActiveAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        return !snapshot.getAllActiveAlerts().isEmpty
    }

    func hasFiringAlerts(for snapshot: RuuviTagCardSnapshot) -> Bool {
        return !snapshot.getAllFiringAlerts().isEmpty
    }

    func validateAlertState(for snapshot: RuuviTagCardSnapshot, physicalSensor: PhysicalSensor) -> Bool {
        // Check measurement-based alerts
        for (measurementType, config) in snapshot.alertData.alertConfigurations {
            guard let alertType = measurementType.toAlertType() else { continue }
            let serviceIsOn = alertService.isOn(type: alertType, for: physicalSensor)
            if serviceIsOn != config.isActive {
                return false
            }
        }

        // Check non-measurement alerts
        for (alertType, config) in snapshot.alertData.nonMeasurementAlerts {
            let serviceIsOn = alertService.isOn(type: alertType, for: physicalSensor)
            if serviceIsOn != config.isActive {
                return false
            }
        }

        return true
    }

    // MARK: - Muted Till Management
    func reloadMutedTillStates(for snapshots: [RuuviTagCardSnapshot]) {
        let currentDate = Date()

        for snapshot in snapshots {
            var hasChanges = false

            // Check measurement-based alerts
            for (measurementType, config) in snapshot.alertData.alertConfigurations {
                if let mutedTill = config.mutedTill, mutedTill < currentDate {
                    let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                        type: config.type,
                        alertType: config.alertType,
                        isActive: config.isActive,
                        isFiring: config.isFiring,
                        mutedTill: nil,
                        lowerBound: config.lowerBound,
                        upperBound: config.upperBound,
                        description: config.description,
                        unseenDuration: config.unseenDuration
                    )
                    snapshot.updateAlertConfig(for: measurementType, config: updatedConfig)
                    hasChanges = true
                }
            }

            // Check non-measurement alerts
            for (alertType, config) in snapshot.alertData.nonMeasurementAlerts {
                if let mutedTill = config.mutedTill, mutedTill < currentDate {
                    let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                        type: config.type,
                        alertType: config.alertType,
                        isActive: config.isActive,
                        isFiring: config.isFiring,
                        mutedTill: nil,
                        lowerBound: config.lowerBound,
                        upperBound: config.upperBound,
                        description: config.description,
                        unseenDuration: config.unseenDuration
                    )
                    snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
                    hasChanges = true
                }
            }

            if hasChanges {
                addToPendingUpdates(snapshotId: snapshot.id)
            }
        }
    }
}

// MARK: - Private Implementation
private extension RuuviTagAlertService {

    // MARK: - Alert Syncing
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func syncMeasurementAlert(
        type: MeasurementType,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: PhysicalSensor
    ) {
        guard let alertType = type.toAlertType() else { return }
        let isOn = alertService.isOn(type: alertType, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)
        let activeAlert = alertService.alert(for: physicalSensor, of: alertType)

        var lowerBound: Double?
        var upperBound: Double?
        var description: String?

        // Get bounds and description based on alert type
        switch activeAlert {
        case let .temperature(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.temperatureDescription(for: physicalSensor)

        case let .relativeHumidity(lower, upper):
            lowerBound = lower * 100.0
            upperBound = upper * 100.0
            description = alertService.relativeHumidityDescription(for: physicalSensor)

        case let .pressure(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.pressureDescription(for: physicalSensor)

        case let .aqi(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.aqiDescription(for: physicalSensor)

        case let .carbonDioxide(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.carbonDioxideDescription(for: physicalSensor)

        case let .pMatter1(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.pm1Description(for: physicalSensor)

        case let .pMatter25(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.pm25Description(for: physicalSensor)

        case let .pMatter4(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.pm4Description(for: physicalSensor)

        case let .pMatter10(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.pm10Description(for: physicalSensor)

        case let .voc(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.vocDescription(for: physicalSensor)

        case let .nox(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.noxDescription(for: physicalSensor)

        case let .soundInstant(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.soundInstantDescription(for: physicalSensor)

        case let .soundPeak(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.soundPeakDescription(for: physicalSensor)

        case let .soundAverage(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.soundAverageDescription(for: physicalSensor)

        case let .luminosity(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.luminosityDescription(for: physicalSensor)

        case let .signal(lower, upper):
            lowerBound = lower
            upperBound = upper
            description = alertService.signalDescription(for: physicalSensor)

        default:
            // Get default bounds from service if not in alert
            lowerBound = getDefaultLowerBound(for: type, physicalSensor: physicalSensor)
            upperBound = getDefaultUpperBound(for: type, physicalSensor: physicalSensor)
            description = getDefaultDescription(for: type, physicalSensor: physicalSensor)
        }

        if let currentConfig = snapshot.getAlertConfig(for: alertType) {
            let newLower = lowerBound ?? currentConfig.lowerBound
            let newUpper = upperBound ?? currentConfig.upperBound
            let newDescription = description ?? currentConfig.description

            let hasChanges = currentConfig.isActive != isOn ||
                currentConfig.mutedTill != mutedTill ||
                !areValuesEqual(currentConfig.lowerBound, newLower) ||
                !areValuesEqual(currentConfig.upperBound, newUpper) ||
                currentConfig.description != newDescription

            if hasChanges {
                let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                    type: currentConfig.type ?? type,
                    alertType: currentConfig.alertType ?? alertType,
                    isActive: isOn,
                    isFiring: currentConfig.isFiring,
                    mutedTill: mutedTill,
                    lowerBound: newLower,
                    upperBound: newUpper,
                    description: newDescription,
                    unseenDuration: currentConfig.unseenDuration
                )
                snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
            }
        } else {
            let config = RuuviTagCardSnapshotAlertConfig(
                type: type,
                alertType: alertType,
                isActive: isOn,
                isFiring: false,
                mutedTill: mutedTill,
                lowerBound: lowerBound,
                upperBound: upperBound,
                description: description
            )
            snapshot.updateAlertConfig(for: type, config: config)
        }
    }

    func syncNonMeasurementAlert(
        type: AlertType,
        snapshot: RuuviTagCardSnapshot,
        physicalSensor: PhysicalSensor
    ) {
        let isOn = alertService.isOn(type: type, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: type, for: physicalSensor)

        var description: String?
        var unseenDuration: Double?

        switch type {
        case .connection:
            description = alertService.connectionDescription(for: physicalSensor)

        case let .cloudConnection(duration):
            description = alertService.cloudConnectionDescription(for: physicalSensor)
            unseenDuration = duration

        case .movement:
            description = alertService.movementDescription(for: physicalSensor)

        default:
            break
        }

        if let currentConfig = snapshot.getAlertConfig(for: type) {
            let newDescription = description ?? currentConfig.description
            let newUnseenDuration = unseenDuration ?? currentConfig.unseenDuration

            let hasChanges = currentConfig.isActive != isOn ||
                currentConfig.mutedTill != mutedTill ||
                currentConfig.description != newDescription ||
                currentConfig.unseenDuration != newUnseenDuration

            if hasChanges {
                let config = RuuviTagCardSnapshotAlertConfig(
                    alertType: currentConfig.alertType ?? type,
                    isActive: isOn,
                    isFiring: currentConfig.isFiring,
                    mutedTill: mutedTill,
                    description: newDescription,
                    unseenDuration: newUnseenDuration
                )

                snapshot.updateAlertConfig(for: type, config: config)
            }
        } else {
            let config = RuuviTagCardSnapshotAlertConfig(
                alertType: type,
                isActive: isOn,
                isFiring: false,
                mutedTill: mutedTill,
                description: description,
                unseenDuration: unseenDuration
            )

            snapshot.updateAlertConfig(for: type, config: config)
        }
    }

    // MARK: - Alert Service Integration
    func observeAlertChanges() {
        alertDidChangeToken?.invalidate()
        alertDidChangeToken = NotificationCenter.default.addObserver(
            forName: .RuuviServiceAlertDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            self.processingLock.lock()
            guard !self.isProcessingAlertChange else {
                self.processingLock.unlock()
                return
            }
            self.processingLock.unlock()

            if let userInfo = notification.userInfo,
               let physicalSensor = userInfo[RuuviServiceAlertDidChangeKey.physicalSensor] as? PhysicalSensor,
               let type = userInfo[RuuviServiceAlertDidChangeKey.type] as? AlertType {

                self.snapshotsQueue.sync { [weak self] in
                    guard let self = self,
                          let snapshot = self.snapshots[physicalSensor.id] else { return }

                    DispatchQueue.main.async {
                        if let measurementType = type.toMeasurementType() {
                            self.syncMeasurementAlert(
                                type: measurementType,
                                snapshot: snapshot,
                                physicalSensor: physicalSensor
                            )
                        } else {
                            self.syncNonMeasurementAlert(
                                type: type,
                                snapshot: snapshot,
                                physicalSensor: physicalSensor
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods
    func createDefaultConfig(for alertType: AlertType) -> RuuviTagCardSnapshotAlertConfig {
        return RuuviTagCardSnapshotAlertConfig(
            type: alertType.toMeasurementType(),
            alertType: alertType,
            isActive: false,
            isFiring: false,
            mutedTill: nil,
            lowerBound: getDefaultLowerBoundValue(for: alertType),
            upperBound: getDefaultUpperBoundValue(for: alertType),
            description: nil,
            unseenDuration: alertType.toMeasurementType() == nil ? 900 : nil
        )
    }

    // MARK: - Service Call Helpers
    // swiftlint:disable:next cyclomatic_complexity
    func setLowerBoundInService(
        type: AlertType,
        value: Double,
        physicalSensor: RuuviTagSensor
    ) {
        switch type {
        case .temperature: alertService.setLower(celsius: value, ruuviTag: physicalSensor)
        case .relativeHumidity: alertService.setLower(relativeHumidity: value / 100.0, ruuviTag: physicalSensor)
        case .pressure: alertService.setLower(pressure: value, ruuviTag: physicalSensor)
        case .aqi: alertService.setLower(aqi: value, ruuviTag: physicalSensor)
        case .carbonDioxide: alertService.setLower(carbonDioxide: value, ruuviTag: physicalSensor)
        case .pMatter1: alertService.setLower(pm1: value, ruuviTag: physicalSensor)
        case .pMatter25: alertService.setLower(pm25: value, ruuviTag: physicalSensor)
        case .pMatter4: alertService.setLower(pm4: value, ruuviTag: physicalSensor)
        case .pMatter10: alertService.setLower(pm10: value, ruuviTag: physicalSensor)
        case .voc: alertService.setLower(voc: value, ruuviTag: physicalSensor)
        case .nox: alertService.setLower(nox: value, ruuviTag: physicalSensor)
        case .soundInstant: alertService.setLower(soundInstant: value, ruuviTag: physicalSensor)
        case .soundAverage: alertService.setLower(soundAverage: value, ruuviTag: physicalSensor)
        case .soundPeak: alertService.setLower(soundPeak: value, ruuviTag: physicalSensor)
        case .luminosity: alertService.setLower(luminosity: value, ruuviTag: physicalSensor)
        case .signal: alertService.setLower(signal: value, ruuviTag: physicalSensor)
        default: break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func setUpperBoundInService(
        type: AlertType,
        value: Double,
        physicalSensor: RuuviTagSensor
    ) {
        switch type {
        case .temperature: alertService.setUpper(celsius: value, ruuviTag: physicalSensor)
        case .relativeHumidity: alertService.setUpper(relativeHumidity: value / 100.0, ruuviTag: physicalSensor)
        case .pressure: alertService.setUpper(pressure: value, ruuviTag: physicalSensor)
        case .aqi: alertService.setUpper(aqi: value, ruuviTag: physicalSensor)
        case .carbonDioxide: alertService.setUpper(carbonDioxide: value, ruuviTag: physicalSensor)
        case .pMatter1: alertService.setUpper(pm1: value, ruuviTag: physicalSensor)
        case .pMatter25: alertService.setUpper(pm25: value, ruuviTag: physicalSensor)
        case .pMatter4: alertService.setUpper(pm4: value, ruuviTag: physicalSensor)
        case .pMatter10: alertService.setUpper(pm10: value, ruuviTag: physicalSensor)
        case .voc: alertService.setUpper(voc: value, ruuviTag: physicalSensor)
        case .nox: alertService.setUpper(nox: value, ruuviTag: physicalSensor)
        case .soundInstant: alertService.setUpper(soundInstant: value, ruuviTag: physicalSensor)
        case .soundAverage: alertService.setUpper(soundAverage: value, ruuviTag: physicalSensor)
        case .soundPeak: alertService.setUpper(soundPeak: value, ruuviTag: physicalSensor)
        case .luminosity: alertService.setUpper(luminosity: value, ruuviTag: physicalSensor)
        case .signal: alertService.setUpper(signal: value, ruuviTag: physicalSensor)
        default: break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func setDescriptionInService(
        type: AlertType,
        description: String?,
        physicalSensor: RuuviTagSensor
    ) {
        switch type {
        case .temperature: alertService.setTemperature(description: description, ruuviTag: physicalSensor)
        case .relativeHumidity: alertService.setRelativeHumidity(description: description, ruuviTag: physicalSensor)
        case .pressure: alertService.setPressure(description: description, ruuviTag: physicalSensor)
        case .aqi: alertService.setAQI(description: description, ruuviTag: physicalSensor)
        case .carbonDioxide: alertService.setCarbonDioxide(description: description, ruuviTag: physicalSensor)
        case .pMatter1: alertService.setPM1(description: description, ruuviTag: physicalSensor)
        case .pMatter25: alertService.setPM25(description: description, ruuviTag: physicalSensor)
        case .pMatter4: alertService.setPM4(description: description, ruuviTag: physicalSensor)
        case .pMatter10: alertService.setPM10(description: description, ruuviTag: physicalSensor)
        case .voc: alertService.setVOC(description: description, ruuviTag: physicalSensor)
        case .nox: alertService.setNOX(description: description, ruuviTag: physicalSensor)
        case .soundInstant: alertService.setSoundInstant(
            description: description,
            ruuviTag: physicalSensor
        )
        case .soundAverage: alertService.setSoundAverage(
            description: description,
            ruuviTag: physicalSensor
        )
        case .soundPeak: alertService.setSoundPeak(
            description: description,
            ruuviTag: physicalSensor
        )
        case .luminosity: alertService.setLuminosity(description: description, ruuviTag: physicalSensor)
        case .signal: alertService.setSignal(description: description, ruuviTag: physicalSensor)
        case .movement: alertService.setMovement(description: description, ruuviTag: physicalSensor)
        case .connection: alertService.setConnection(description: description, for: physicalSensor)
        case .cloudConnection: alertService.setCloudConnection(description: description, ruuviTag: physicalSensor)
        default: break
        }
    }

    // MARK: - Default Values
    // swiftlint:disable:next cyclomatic_complexity
    func getDefaultLowerBound(for type: MeasurementType, physicalSensor: PhysicalSensor) -> Double? {
        switch type {
        case .temperature: return alertService.lowerCelsius(for: physicalSensor)
        case .humidity: return alertService.lowerRelativeHumidity(for: physicalSensor).map { $0 * 100.0 }
        case .pressure: return alertService.lowerPressure(for: physicalSensor)
        case .aqi: return alertService.lowerAQI(for: physicalSensor)
        case .co2: return alertService.lowerCarbonDioxide(for: physicalSensor)
        case .pm10: return alertService.lowerPM1(for: physicalSensor)
        case .pm25: return alertService.lowerPM25(for: physicalSensor)
        case .pm40: return alertService.lowerPM4(for: physicalSensor)
        case .pm100: return alertService.lowerPM10(for: physicalSensor)
        case .voc: return alertService.lowerVOC(for: physicalSensor)
        case .nox: return alertService.lowerNOX(for: physicalSensor)
        case .soundInstant: return alertService.lowerSoundInstant(for: physicalSensor)
        case .soundAverage: return alertService.lowerSoundAverage(
            for: physicalSensor
        )
        case .soundPeak: return alertService.lowerSoundPeak(for: physicalSensor)
        case .luminosity: return alertService.lowerLuminosity(for: physicalSensor)
        default: return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getDefaultUpperBound(for type: MeasurementType, physicalSensor: PhysicalSensor) -> Double? {
        switch type {
        case .temperature: return alertService.upperCelsius(for: physicalSensor)
        case .humidity: return alertService.upperRelativeHumidity(for: physicalSensor).map { $0 * 100.0 }
        case .pressure: return alertService.upperPressure(for: physicalSensor)
        case .aqi: return alertService.upperAQI(for: physicalSensor)
        case .co2: return alertService.upperCarbonDioxide(for: physicalSensor)
        case .pm10: return alertService.upperPM1(for: physicalSensor)
        case .pm25: return alertService.upperPM25(for: physicalSensor)
        case .pm40: return alertService.upperPM4(for: physicalSensor)
        case .pm100: return alertService.upperPM10(for: physicalSensor)
        case .voc: return alertService.upperVOC(for: physicalSensor)
        case .nox: return alertService.upperNOX(for: physicalSensor)
        case .soundInstant: return alertService.upperSoundInstant(for: physicalSensor)
        case .soundAverage: return alertService.upperSoundAverage(for: physicalSensor)
        case .soundPeak: return alertService.upperSoundPeak(
            for: physicalSensor
        )
        case .luminosity: return alertService.upperLuminosity(for: physicalSensor)
        default: return nil
        }
    }

    func areValuesEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (l?, r?):
            return abs(l - r) < 0.0001
        default:
            return false
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getDefaultDescription(for type: MeasurementType, physicalSensor: PhysicalSensor) -> String? {
        switch type {
        case .temperature: return alertService.temperatureDescription(for: physicalSensor)
        case .humidity: return alertService.relativeHumidityDescription(for: physicalSensor)
        case .pressure: return alertService.pressureDescription(for: physicalSensor)
        case .aqi: return alertService.aqiDescription(for: physicalSensor)
        case .co2: return alertService.carbonDioxideDescription(for: physicalSensor)
        case .pm10: return alertService.pm1Description(for: physicalSensor)
        case .pm25: return alertService.pm25Description(for: physicalSensor)
        case .pm40: return alertService.pm4Description(for: physicalSensor)
        case .pm100: return alertService.pm10Description(for: physicalSensor)
        case .voc: return alertService.vocDescription(for: physicalSensor)
        case .nox: return alertService.noxDescription(for: physicalSensor)
        case .soundInstant: return alertService.soundInstantDescription(for: physicalSensor)
        case .soundAverage: return alertService.soundAverageDescription(for: physicalSensor)
        case .soundPeak: return alertService.soundPeakDescription(for: physicalSensor)
        case .luminosity: return alertService.luminosityDescription(for: physicalSensor)
        default: return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getDefaultLowerBoundValue(for alertType: AlertType) -> Double? {
        switch alertType {
        case .temperature: return RuuviAlertConstants.Temperature.lowerBound
        case .relativeHumidity: return RuuviAlertConstants.RelativeHumidity.lowerBound
        case .pressure: return RuuviAlertConstants.Pressure.lowerBound
        case .aqi: return RuuviAlertConstants.AQI.lowerBound
        case .carbonDioxide: return RuuviAlertConstants.CarbonDioxide.lowerBound
        case .pMatter1,
             .pMatter25,
             .pMatter4,
             .pMatter10: return RuuviAlertConstants.ParticulateMatter.lowerBound
        case .voc: return RuuviAlertConstants.VOC.lowerBound
        case .nox: return RuuviAlertConstants.NOX.lowerBound
        case .soundInstant, .soundAverage, .soundPeak: return RuuviAlertConstants.Sound.lowerBound
        case .luminosity: return RuuviAlertConstants.Luminosity.lowerBound
        case .signal: return RuuviAlertConstants.Signal.lowerBound
        default: return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func getDefaultUpperBoundValue(for alertType: AlertType) -> Double? {
        switch alertType {
        case .temperature: return RuuviAlertConstants.Temperature.upperBound
        case .relativeHumidity: return RuuviAlertConstants.RelativeHumidity.upperBound
        case .pressure: return RuuviAlertConstants.Pressure.upperBound
        case .aqi: return RuuviAlertConstants.AQI.upperBound
        case .carbonDioxide: return RuuviAlertConstants.CarbonDioxide.upperBound
        case .pMatter1,
             .pMatter25,
             .pMatter4,
             .pMatter10: return RuuviAlertConstants.ParticulateMatter.upperBound
        case .voc: return RuuviAlertConstants.VOC.upperBound
        case .nox: return RuuviAlertConstants.NOX.upperBound
        case .soundInstant, .soundAverage, .soundPeak: return RuuviAlertConstants.Sound.upperBound
        case .luminosity: return RuuviAlertConstants.Luminosity.upperBound
        case .signal: return RuuviAlertConstants.Signal.upperBound
        default: return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func createAlertTypeWithBounds(
        _ alertType: AlertType,
        config: RuuviTagCardSnapshotAlertConfig
    ) -> AlertType {
        switch alertType {
        case .temperature:
            return .temperature(
                lower: config.lowerBound ?? RuuviAlertConstants.Temperature.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Temperature.upperBound
            )

        case .relativeHumidity:
            return .relativeHumidity(
                lower: (config.lowerBound ?? RuuviAlertConstants.RelativeHumidity.lowerBound) / 100.0,
                upper: (config.upperBound ?? RuuviAlertConstants.RelativeHumidity.upperBound) / 100.0
            )

        case .pressure:
            return .pressure(
                lower: config.lowerBound ?? RuuviAlertConstants.Pressure.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Pressure.upperBound
            )
        case .aqi:
            return .aqi(
                lower: config.lowerBound ?? RuuviAlertConstants.AQI.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.AQI.upperBound
            )

        case .carbonDioxide:
            return .carbonDioxide(
                lower: config.lowerBound ?? RuuviAlertConstants.CarbonDioxide.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.CarbonDioxide.upperBound
            )

        case .pMatter1:
            return .pMatter1(
                lower: config.lowerBound ?? RuuviAlertConstants.ParticulateMatter.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.ParticulateMatter.upperBound
            )
        case .pMatter25:
            return .pMatter25(
                lower: config.lowerBound ?? RuuviAlertConstants.ParticulateMatter.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.ParticulateMatter.upperBound
            )
        case .pMatter4:
            return .pMatter4(
                lower: config.lowerBound ?? RuuviAlertConstants.ParticulateMatter.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.ParticulateMatter.upperBound
            )
        case .pMatter10:
            return .pMatter10(
                lower: config.lowerBound ?? RuuviAlertConstants.ParticulateMatter.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.ParticulateMatter.upperBound
            )

        case .voc:
            return .voc(
                lower: config.lowerBound ?? RuuviAlertConstants.VOC.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.VOC.upperBound
            )

        case .nox:
            return .nox(
                lower: config.lowerBound ?? RuuviAlertConstants.NOX.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.NOX.upperBound
            )

        case .soundInstant:
            return .soundInstant(
                lower: config.lowerBound ?? RuuviAlertConstants.Sound.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Sound.upperBound
            )

        case .soundAverage:
            return .soundAverage(
                lower: config.lowerBound ?? RuuviAlertConstants.Sound.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Sound.upperBound
            )

        case .soundPeak:
            return .soundPeak(
                lower: config.lowerBound ?? RuuviAlertConstants.Sound.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Sound.upperBound
            )

        case .luminosity:
            return .luminosity(
                lower: config.lowerBound ?? RuuviAlertConstants.Luminosity.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Luminosity.upperBound
            )

        case .signal:
            return .signal(
                lower: config.lowerBound ?? RuuviAlertConstants.Signal.lowerBound,
                upper: config.upperBound ?? RuuviAlertConstants.Signal.upperBound
            )

        case .movement:
            return .movement(last: 0) // no bounds

        case .cloudConnection:
            return .cloudConnection(
                unseenDuration: config.unseenDuration ?? Double(
                    RuuviAlertConstants.CloudConnection.defaultUnseenDuration
                )
            )

        default:
            return alertType
        }
    }
    // MARK: - Debouncing Helper
    func getDebouncerForKey(_ key: String) -> Debouncer {
        if let existingDebouncer = debouncers[key] {
            return existingDebouncer
        } else {
            let newDebouncer = Debouncer(delay: lowUpperDebounceDelay)
            debouncers[key] = newDebouncer
            return newDebouncer
        }
    }

    // MARK: - Debouncing
    func addToPendingUpdates(snapshotId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.pendingUpdates.insert(snapshotId)
            self.debounceTimer?.invalidate()

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
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.delegate?.alertService(self, didUpdateSnapshot: snapshot)
                    }
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.alertService(self, alertsDidChange: true)
        }
    }

    func findSnapshotByIdentifier(_ identifier: String) -> RuuviTagCardSnapshot? {
        if let snapshot = snapshots[identifier] {
            return snapshot
        }

        return snapshots.values.first { snapshot in
            snapshot.identifierData.luid?.value == identifier ||
            snapshot.identifierData.mac?.value == identifier
        }
    }
}

// MARK: - RuuviNotifierObserver
extension RuuviTagAlertService: RuuviNotifierObserver {

    func ruuvi(notifier: RuuviNotifier, isTriggered: Bool, for uuid: String) {
        // No op.
    }

    // swiftlint:disable:next function_body_length
    func ruuvi(
        notifier: RuuviNotifier,
        alertType: AlertType,
        isTriggered: Bool,
        for uuid: String
    ) {
        snapshotsQueue.sync { [weak self] in
            guard let self = self,
                  let snapshot = self.findSnapshotByIdentifier(uuid) else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.processingLock.lock()
                guard !self.isProcessingAlertChange else {
                    self.processingLock.unlock()
                    return
                }
                self.isProcessingAlertChange = true
                self.processingLock.unlock()

                let isFireable = snapshot.metadata.isCloud ||
                                snapshot.connectionData.isConnected ||
                                snapshot.identifierData.serviceUUID != nil

                let isTriggeredAndFireable = isTriggered && isFireable
                let isFiring = isTriggeredAndFireable

                let isOn = self.alertService.isOn(type: alertType, for: uuid)
                let mutedTill = self.alertService.mutedTill(type: alertType, for: uuid)

                if let currentConfig = snapshot.getAlertConfig(for: alertType) {
                    // Check if any values actually changed
                    let hasChanges = currentConfig.isActive != isOn ||
                                   currentConfig.isFiring != isFiring ||
                                   currentConfig.mutedTill != mutedTill

                    if hasChanges {
                        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
                            type: currentConfig.type,
                            alertType: currentConfig.alertType,
                            isActive: isOn,
                            isFiring: isFiring,
                            mutedTill: mutedTill,
                            lowerBound: currentConfig.lowerBound,
                            upperBound: currentConfig.upperBound,
                            description: currentConfig.description,
                            unseenDuration: currentConfig.unseenDuration
                        )
                        snapshot.updateAlertConfig(for: alertType, config: updatedConfig)
                        self.addToPendingUpdates(snapshotId: snapshot.id)
                    }
                } else {
                    if let measurementType = alertType.toMeasurementType() {
                        let newConfig = RuuviTagCardSnapshotAlertConfig(
                            type: measurementType,
                            alertType: alertType,
                            isActive: isOn,
                            isFiring: isFiring,
                            mutedTill: mutedTill,
                            lowerBound: nil,
                            upperBound: nil,
                            description: nil,
                            unseenDuration: nil
                        )
                        snapshot
                            .updateAlertConfig(
                                for: alertType,
                                config: newConfig
                            )
                        self.addToPendingUpdates(snapshotId: snapshot.id)
                    }
                }
                self.processingLock.lock()
                self.isProcessingAlertChange = false
                self.processingLock.unlock()
            }
        }
    }
}

// MARK: - Push Notification Helpers
private extension RuuviTagAlertService {
    func refreshPushNotificationStatus() {
        pushNotificationsManager.getRemoteNotificationsAuthorizationStatus { [weak self] status in
            guard let self else { return }

            var enabled = false
            switch status {
            case .authorized:
                enabled = true
            case .denied:
                enabled = false
            case .notDetermined:
                enabled = false
                DispatchQueue.main.async {
                    self.pushNotificationsManager.registerForRemoteNotifications()
                }
            @unknown default:
                enabled = false
            }

            DispatchQueue.main.async {
                let previousLoaded = self.pushNotificationStatusLoaded
                let prevEnabled = self.pushNotificationsEnabled
                self.pushNotificationsEnabled = enabled
                self.pushNotificationStatusLoaded = true
                if !previousLoaded || prevEnabled != enabled {
                    self.updatePushCapabilitiesForAllSnapshots()
                }
            }
        }
    }

    func schedulePushCapabilityUpdate(for snapshot: RuuviTagCardSnapshot) {
        guard pushNotificationStatusLoaded else { return }
        DispatchQueue.main.async { [weak self] in
            self?.applyPushCapabilities(to: snapshot)
        }
    }

    func schedulePushCapabilityUpdate(for snapshots: [RuuviTagCardSnapshot]) {
        guard pushNotificationStatusLoaded else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            snapshots.forEach { self.applyPushCapabilities(to: $0) }
        }
    }

    func updatePushCapabilitiesForAllSnapshots() {
        guard pushNotificationStatusLoaded else { return }
        snapshotsQueue.async { [weak self] in
            guard let self else { return }
            let snapshots = Array(self.snapshots.values)
            guard !snapshots.isEmpty else { return }
            DispatchQueue.main.async {
                snapshots.forEach { self.applyPushCapabilities(to: $0) }
            }
        }
    }

    func applyPushCapabilities(to snapshot: RuuviTagCardSnapshot) {
        guard pushNotificationStatusLoaded else { return }
        let enabled = pushNotificationsEnabled
        let canDeliverPush = snapshot.metadata.isCloud || snapshot.connectionData.isConnectable
        let available = enabled && canDeliverPush
        if snapshot.capabilities.isPushNotificationsEnabled != enabled ||
            snapshot.capabilities.isPushNotificationsAvailable != available {
            snapshot.capabilities.isPushNotificationsEnabled = enabled
            snapshot.capabilities.isPushNotificationsAvailable = available
            addToPendingUpdates(snapshotId: snapshot.id)
        }
    }

    func ensureMutedTillRefreshTimer() {
        guard muteRefreshActive else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.muteRefreshTimer == nil else { return }
            self.muteRefreshTimer = Timer.scheduledTimer(
                withTimeInterval: self.muteRefreshInterval,
                repeats: true
            ) { [weak self] _ in
                self?.refreshMutedTillStatesIfNeeded()
            }
        }
    }

    func stopMutedTillRefreshTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.muteRefreshTimer?.invalidate()
            self.muteRefreshTimer = nil
        }
    }

    func refreshMutedTillStatesIfNeeded() {
        snapshotsQueue.async { [weak self] in
            guard let self else { return }
            guard self.muteRefreshActive else { return }
            let snapshots = Array(self.snapshots.values)
            guard !snapshots.isEmpty else {
                self.stopMutedTillRefreshTimer()
                return
            }
            DispatchQueue.main.async {
                self.reloadMutedTillStates(for: snapshots)
            }
        }
    }
}

// swiftlint:enable file_length
