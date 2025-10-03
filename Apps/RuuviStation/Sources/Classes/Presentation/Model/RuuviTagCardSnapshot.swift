// swiftlint:disable file_length

import UIKit
import Combine
import RuuviOntology
import RuuviLocal
import RuuviLocalization
import Humidity
import RuuviService

public final class RuuviTagCardSnapshot: ObservableObject, Hashable, Equatable {

    // MARK: - Identifier
    let id: String
    let identifierData: RuuviTagCardSnapshotIdentityData

    var latestRawRecord: RuuviTagSensorRecord?

    // MARK: - Published Properties
    @Published var displayData: RuuviTagCardSnapshotDisplayData
    @Published var metadata: RuuviTagCardSnapshotMetadata
    @Published var alertData: RuuviTagCardSnapshotAlertData
    @Published var connectionData: RuuviTagCardSnapshotConnectionData
    @Published var lastUpdated: Date?

    public var anyIndicatorAlertPublisher: AnyPublisher<[RuuviTagCardSnapshotAlertConfig], Never> {
        return $displayData
            .map { displayData -> [RuuviTagCardSnapshotAlertConfig] in
                return displayData.indicatorGrid?.indicators.compactMap { indicator in
                    self.getAlertConfig(for: indicator.type)
                } ?? []
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    // MARK: - Internal properties for change detection
    private var cancellables = Set<AnyCancellable>()

    init(
        id: String,
        identifierData: RuuviTagCardSnapshotIdentityData,
        displayData: RuuviTagCardSnapshotDisplayData = RuuviTagCardSnapshotDisplayData(),
        metadata: RuuviTagCardSnapshotMetadata = RuuviTagCardSnapshotMetadata(),
        alertData: RuuviTagCardSnapshotAlertData = RuuviTagCardSnapshotAlertData(),
        connectionData: RuuviTagCardSnapshotConnectionData = RuuviTagCardSnapshotConnectionData(),
        lastUpdated: Date?
    ) {
        self.id = id
        self.identifierData = identifierData
        self.displayData = displayData
        self.alertData = alertData
        self.connectionData = connectionData
        self.lastUpdated = lastUpdated
        self.metadata = metadata
    }

    // MARK: - Hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Equatable
    public static func == (lhs: RuuviTagCardSnapshot, rhs: RuuviTagCardSnapshot) -> Bool {
        return lhs.id == rhs.id &&
        lhs.identifierData == rhs.identifierData &&
        lhs.displayData == rhs.displayData &&
        lhs.metadata == rhs.metadata &&
        lhs.alertData == rhs.alertData &&
        lhs.connectionData == rhs.connectionData &&
        lhs.lastUpdated == rhs.lastUpdated
    }
}

// MARK: - Structured Data Models
struct RuuviTagCardSnapshotIdentityData: Equatable {
    var luid: LocalIdentifier?
    var mac: MACIdentifier?
    var serviceUUID: String?

    static func == (
        lhs: RuuviTagCardSnapshotIdentityData,
        rhs: RuuviTagCardSnapshotIdentityData
    ) -> Bool {
        return lhs.luid?.any == rhs.luid?.any &&
        lhs.mac?.any == rhs.mac?.any &&
        lhs.serviceUUID == rhs.serviceUUID
    }
}

struct RuuviTagCardSnapshotDisplayData: Equatable {
    var name: String = ""
    var version: Int?
    var background: UIImage?
    var source: RuuviTagSensorRecordSource?
    var batteryNeedsReplacement: Bool = false
    var indicatorGrid: RuuviTagCardSnapshotIndicatorGridConfiguration?
    var hasNoData: Bool = false
    var networkSyncStatus: NetworkSyncStatus = .none

    static func == (
        lhs: RuuviTagCardSnapshotDisplayData,
        rhs: RuuviTagCardSnapshotDisplayData
    ) -> Bool {
        return lhs.name == rhs.name &&
        lhs.version == rhs.version &&
        lhs.background === rhs.background &&
        lhs.source == rhs.source &&
        lhs.batteryNeedsReplacement == rhs.batteryNeedsReplacement &&
        lhs.indicatorGrid == rhs.indicatorGrid &&
        lhs.hasNoData == rhs.hasNoData &&
        lhs.networkSyncStatus == rhs.networkSyncStatus
    }
}

struct RuuviTagCardSnapshotConnectionData: Equatable {
    var isConnected: Bool = false
    var isConnectable: Bool = false
    var keepConnection: Bool = false

    static func == (
        lhs: RuuviTagCardSnapshotConnectionData,
        rhs: RuuviTagCardSnapshotConnectionData
    ) -> Bool {
        return lhs.isConnected == rhs.isConnected &&
        lhs.isConnectable == rhs.isConnectable &&
        lhs.keepConnection == rhs.keepConnection
    }
}

struct RuuviTagCardSnapshotMetadata: Equatable {
    var isChartAvailable: Bool = false
    var isAlertAvailable: Bool = false
    var isCloud: Bool = false
    var isOwner: Bool = false
    var canShareTag: Bool = false

    static func == (
        lhs: RuuviTagCardSnapshotMetadata,
        rhs: RuuviTagCardSnapshotMetadata
    ) -> Bool {
        return lhs.isChartAvailable == rhs.isChartAvailable &&
            lhs.isAlertAvailable == rhs.isAlertAvailable &&
            lhs.isCloud == rhs.isCloud &&
            lhs.isOwner == rhs.isOwner &&
            lhs.canShareTag == rhs.canShareTag
    }
}

// MARK: - Alert Data Structures
struct RuuviTagCardSnapshotAlertData: Equatable {
    var alertState: AlertState?
    var hasActiveAlerts: Bool = false
    var alertConfigurations: [MeasurementType: RuuviTagCardSnapshotAlertConfig] = [:]
    var nonMeasurementAlerts: [AlertType: RuuviTagCardSnapshotAlertConfig] = [:]

    static func == (
        lhs: RuuviTagCardSnapshotAlertData,
        rhs: RuuviTagCardSnapshotAlertData
    ) -> Bool {
        return lhs.alertState == rhs.alertState &&
        lhs.hasActiveAlerts == rhs.hasActiveAlerts &&
        lhs.alertConfigurations == rhs.alertConfigurations &&
        lhs.nonMeasurementAlerts == rhs.nonMeasurementAlerts
    }
}

public struct RuuviTagCardSnapshotAlertConfig: Equatable {
    let type: MeasurementType?
    let alertType: AlertType?
    let isActive: Bool
    let isFiring: Bool
    let mutedTill: Date?
    let lowerBound: Double?
    let upperBound: Double?
    let description: String?
    let unseenDuration: Double?

    static let inactive = RuuviTagCardSnapshotAlertConfig(
        type: .temperature,
        alertType: .temperature(lower: 0, upper: 0),
        isActive: false,
        isFiring: false,
        mutedTill: nil,
        lowerBound: nil,
        upperBound: nil,
        description: nil,
        unseenDuration: nil
    )

    var isHighlighted: Bool {
        return isActive && isFiring
    }

    init(
        type: MeasurementType? = nil,
        alertType: AlertType? = nil,
        isActive: Bool,
        isFiring: Bool,
        mutedTill: Date?,
        lowerBound: Double? = nil,
        upperBound: Double? = nil,
        description: String? = nil,
        unseenDuration: Double? = nil
    ) {
        self.type = type
        self.alertType = alertType
        self.isActive = isActive
        self.isFiring = isFiring
        self.mutedTill = mutedTill
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.description = description
        self.unseenDuration = unseenDuration
    }
}

// MARK: - Pre-configured Indicator Grid
// swiftlint:disable:next type_name
struct RuuviTagCardSnapshotIndicatorGridConfiguration: Equatable {
    let indicators: [RuuviTagCardSnapshotIndicatorData]
    let dashboardLayoutType: DashboardGridLayoutType

    enum DashboardGridLayoutType: String, Equatable {
        case vertical    // < 3 indicators
        case grid        // >= 3 indicators in 2-column grid
    }

    var layoutType_computed: DashboardGridLayoutType {
        return indicators.count < 3 ? .vertical : .grid
    }

    init(indicators: [RuuviTagCardSnapshotIndicatorData]) {
        self.indicators = indicators
        self.dashboardLayoutType = indicators.count < 3 ? .vertical : .grid
    }
}

struct RuuviTagCardSnapshotIndicatorData: Equatable, Hashable {
    let type: MeasurementType
    let value: String
    let unit: String
    let isProminent: Bool
    let showSubscript: Bool
    let tintColor: UIColor?
    let qualityState: MeasurementQualityState?

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }
}

// MARK: - Alert Access Methods
extension RuuviTagCardSnapshot {

    // MARK: - Alert Configuration Access
    func getAlertConfig(for measurementType: MeasurementType) -> RuuviTagCardSnapshotAlertConfig? {
        return alertData.alertConfigurations[measurementType]
    }

    func getAlertConfig(for alertType: AlertType) -> RuuviTagCardSnapshotAlertConfig? {
        if let measurementType = alertType.toMeasurementType() {
            return alertData.alertConfigurations[measurementType]
        }
        return alertData.nonMeasurementAlerts[alertType]
    }

    func getAllActiveAlerts() -> [RuuviTagCardSnapshotAlertConfig] {
        let measurementAlerts = alertData.alertConfigurations.values.filter { $0.isActive }
        let nonMeasurementAlerts = alertData.nonMeasurementAlerts.values.filter { $0.isActive }
        return Array(measurementAlerts) + Array(nonMeasurementAlerts)
    }

    func getAllFiringAlerts() -> [RuuviTagCardSnapshotAlertConfig] {
        return getAllActiveAlerts().filter { $0.isFiring }
    }

    // MARK: - Indicator Alert Access
    func getIndicatorAlertConfig(for indicator: RuuviTagCardSnapshotIndicatorData) -> RuuviTagCardSnapshotAlertConfig {
        return getAlertConfig(for: indicator.type) ?? .inactive
    }

    func isIndicatorHighlighted(for indicator: RuuviTagCardSnapshotIndicatorData) -> Bool {
        return getIndicatorAlertConfig(for: indicator).isHighlighted
    }

    // MARK: - Alert Configuration Updates
    func updateAlertConfig(
        for measurementType: MeasurementType,
        config: RuuviTagCardSnapshotAlertConfig
    ) {
        alertData.alertConfigurations[measurementType] = config
        updateOverallAlertState()
    }

    func updateAlertConfig(
        for alertType: AlertType,
        config: RuuviTagCardSnapshotAlertConfig
    ) {
        if let measurementType = alertType.toMeasurementType() {
            alertData.alertConfigurations[measurementType] = config
        } else {
            alertData.nonMeasurementAlerts[alertType] = config
        }
        updateOverallAlertState()
    }

    func removeAlertConfig(for measurementType: MeasurementType) {
        alertData.alertConfigurations.removeValue(forKey: measurementType)
        updateOverallAlertState()
    }

    func removeAlertConfig(for alertType: AlertType) {
        if let measurementType = alertType.toMeasurementType() {
            alertData.alertConfigurations.removeValue(forKey: measurementType)
        } else {
            alertData.nonMeasurementAlerts.removeValue(forKey: alertType)
        }
        updateOverallAlertState()
    }
}

// MARK: - Snapshot Update Methods
extension RuuviTagCardSnapshot {

    // MARK: - Update Metadata
    func updateMetadata(
        isConnected: Bool? = nil,
        serviceUUID: String? = nil,
        isCloud: Bool? = nil,
        isOwner: Bool? = nil,
        isConnectable: Bool? = nil
    ) {
        // Calculate isAlertAvailable based on connection status, serviceUUID, and cloud status
        let currentIsConnected = isConnected ?? self.connectionData.isConnected
        let currentServiceUUID = serviceUUID ?? self.identifierData.serviceUUID
        let currentIsCloud = isCloud ?? self.metadata.isCloud

        let newIsAlertAvailable = currentIsConnected ||
                                  currentServiceUUID != nil ||
                                  currentIsCloud

        // Update isAlertAvailable if it changed
        if self.metadata.isAlertAvailable != newIsAlertAvailable {
            self.metadata.isAlertAvailable = newIsAlertAvailable
        }

        // Update other metadata properties if provided
        if let isCloud = isCloud, self.metadata.isCloud != isCloud {
            self.metadata.isCloud = isCloud
        }

        if let isOwner = isOwner, self.metadata.isOwner != isOwner {
            self.metadata.isOwner = isOwner
        }

        let currentIsConnectable = isConnectable ?? self.connectionData.isConnectable
        let newIsChartAvailable = currentIsConnectable ||
                                  currentServiceUUID != nil ||
                                  currentIsCloud
        if self.metadata.isChartAvailable != newIsChartAvailable {
            self.metadata.isChartAvailable = newIsChartAvailable
        }

        // Update canShareTag based on current values
        let newCanShareTag = self.metadata.isOwner && !self.metadata.isCloud
        if self.metadata.canShareTag != newCanShareTag {
            self.metadata.canShareTag = newCanShareTag
        }
    }

    // MARK: - Update Connection Data
    func updateConnectionData(
        isConnected: Bool,
        isConnectable: Bool,
        keepConnection: Bool
    ) {
        let newConnectionData = RuuviTagCardSnapshotConnectionData(
            isConnected: isConnected,
            isConnectable: isConnectable,
            keepConnection: keepConnection
        )

        // Only update if connection data actually changed
        guard self.connectionData != newConnectionData else { return }

        self.connectionData = newConnectionData

        // Update metadata when connection data changes
        updateMetadata(isConnected: isConnected, isConnectable: isConnectable)
    }

    // MARK: - Update Background Image
    func updateBackgroundImage(_ image: UIImage?) {
        // Only update if image actually changed
        guard self.displayData.background !== image else { return }

        self.displayData.background = image
    }

    // MARK: - Update Network Sync Status
    func updateNetworkSyncStatus(_ status: NetworkSyncStatus) {
        // Only update if status actually changed
        guard self.displayData.networkSyncStatus != status else { return }

        self.displayData.networkSyncStatus = status
    }

    // MARK: - Legacy Alert Update Method (for backward compatibility)
    func updateAlert(
        for type: MeasurementType,
        isOn: Bool,
        alertState: AlertState?,
        mutedTill: Date?
    ) {
        let config = RuuviTagCardSnapshotAlertConfig(
            type: type,
            alertType: type.toAlertType(),
            isActive: isOn,
            isFiring: alertState == .firing,
            mutedTill: mutedTill
        )

        updateAlertConfig(for: type, config: config)
    }

    // MARK: - Update Overall Alert State
    private func updateOverallAlertState() {
        let allAlerts = getAllActiveAlerts()
        let hasFiringAlert = allAlerts.contains { $0.isFiring }
        let hasActiveAlert = !allAlerts.isEmpty

        let newAlertState: AlertState
        let newHasActiveAlerts: Bool

        if hasFiringAlert {
            newAlertState = .firing
            newHasActiveAlerts = true
        } else if hasActiveAlert {
            newAlertState = .registered
            newHasActiveAlerts = false
        } else {
            newAlertState = .empty
            newHasActiveAlerts = false
        }

        // Only update if state actually changed
        if self.alertData.alertState != newAlertState ||
           self.alertData.hasActiveAlerts != newHasActiveAlerts {
            self.alertData.alertState = newAlertState
            self.alertData.hasActiveAlerts = newHasActiveAlerts
        }
    }

    // MARK: - Sync All Alerts from Service
    func syncAllAlerts(
        from alertService: RuuviServiceAlert,
        physicalSensor: PhysicalSensor
    ) {
        // Sync measurement-based alerts
        for measurementType in MeasurementType.all {
            let alertType = measurementType.toAlertType()
            let isOn = alertService.isOn(type: alertType, for: physicalSensor)
            let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

            let config = RuuviTagCardSnapshotAlertConfig(
                type: measurementType,
                alertType: alertType,
                isActive: isOn,
                isFiring: false, // Will be updated by alert handler
                mutedTill: mutedTill
            )

            alertData.alertConfigurations[measurementType] = config
        }

        // Sync non-measurement alerts
        let nonMeasurementAlertTypes: [AlertType] = [
            .connection, .cloudConnection(unseenDuration: 0), .movement(last: 0)
        ]
        for alertType in nonMeasurementAlertTypes {
            let isOn = alertService.isOn(type: alertType, for: physicalSensor)
            let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

            let config = RuuviTagCardSnapshotAlertConfig(
                alertType: alertType,
                isActive: isOn,
                isFiring: false,
                mutedTill: mutedTill
            )

            alertData.nonMeasurementAlerts[alertType] = config
        }

        updateOverallAlertState()
    }

    // MARK: - Update from RuuviTagSensorRecord
    func updateFromRecord(
        _ record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        sensorSettings: SensorSettings? = nil
    ) {
        // Apply sensor settings to record if available
        let finalRecord = sensorSettings != nil ? record.with(sensorSettings: sensorSettings) : record

        // Check if the record actually changed (by comparing dates)
        let recordChanged = latestRawRecord?.date != finalRecord.date

        latestRawRecord = finalRecord

        // Update display data only if record changed
        if recordChanged {
            let oldSource = self.displayData.source
            let oldHasNoData = self.displayData.hasNoData
            let oldBatteryNeedsReplacement = self.displayData.batteryNeedsReplacement

            self.displayData.source = finalRecord.source
            self.displayData.hasNoData = false

            // Update battery status
            let batteryStatusProvider = RuuviTagBatteryStatusProvider()
            let newBatteryNeedsReplacement = batteryStatusProvider.batteryNeedsReplacement(
                temperature: finalRecord.temperature,
                voltage: finalRecord.voltage
            )
            self.displayData.batteryNeedsReplacement = newBatteryNeedsReplacement

            // Create indicator grid from record and sensor data
            let newIndicatorGrid = RuuviTagCardSnapshotDataBuilder.createIndicatorGrid(
                from: finalRecord,
                sensor: sensor,
                measurementService: measurementService,
                flags: flags,
                snapshot: self
            )

            // Check if any display data actually changed
            if oldSource != self.displayData.source ||
               oldHasNoData != self.displayData.hasNoData ||
               oldBatteryNeedsReplacement != newBatteryNeedsReplacement ||
               self.displayData.indicatorGrid != newIndicatorGrid {
                self.displayData.indicatorGrid = newIndicatorGrid
            }
        }

        // Always check sensor name/version changes (these can change independently of records)
        if self.displayData.name != sensor.name || self.displayData.version != sensor.version {
            self.displayData.name = sensor.name
            self.displayData.version = sensor.version
        }

        // Update timestamp only if it actually changed
        if self.lastUpdated != finalRecord.date {
            self.lastUpdated = finalRecord.date
        }
    }
}

// MARK: - Factory Methods
extension RuuviTagCardSnapshot {

    // MARK: - Create from Basic Parameters
    // swiftlint:disable:next function_parameter_count
    static func create(
        id: String,
        name: String,
        luid: LocalIdentifier?,
        mac: MACIdentifier?,
        serviceUUID: String?,
        isCloud: Bool,
        isOwner: Bool,
        isConnectable: Bool,
        version: Int?
    ) -> RuuviTagCardSnapshot {

        let identifierData = RuuviTagCardSnapshotIdentityData(
            luid: luid,
            mac: mac,
            serviceUUID: serviceUUID
        )

        let displayData = RuuviTagCardSnapshotDisplayData(
            name: name,
            version: version,
            background: nil,
            source: nil,
            batteryNeedsReplacement: false,
            indicatorGrid: nil,
            hasNoData: true,
            networkSyncStatus: .none
        )

        let connectionData = RuuviTagCardSnapshotConnectionData(
            isConnected: false,
            isConnectable: isConnectable,
            keepConnection: false
        )

        let metadata = RuuviTagCardSnapshotMetadata(
            isChartAvailable: isConnectable || isCloud,
            isAlertAvailable: serviceUUID != nil || isCloud,
            isCloud: isCloud,
            isOwner: isOwner,
            canShareTag: isOwner && !isCloud
        )

        let alertData = RuuviTagCardSnapshotAlertData()

        return RuuviTagCardSnapshot(
            id: id,
            identifierData: identifierData,
            displayData: displayData,
            metadata: metadata,
            alertData: alertData,
            connectionData: connectionData,
            lastUpdated: nil
        )
    }
}

// MARK: - Helper Methods for Change Detection
extension RuuviTagCardSnapshot {

    // MARK: - Calculate Alert Availability
    private func calculateIsAlertAvailable() -> Bool {
        return connectionData.isConnected ||
               identifierData.serviceUUID != nil ||
               metadata.isCloud
    }

    /// Check if this snapshot has significant changes compared to another
    func hasSignificantChanges(from other: RuuviTagCardSnapshot) -> Bool {
        return self.displayData != other.displayData ||
               self.alertData != other.alertData ||
               self.connectionData != other.connectionData ||
               self.lastUpdated != other.lastUpdated
    }

    /// Get a summary of what changed
    func changesSummary(from other: RuuviTagCardSnapshot) -> String {
        var changes: [String] = []

        if self.displayData != other.displayData {
            changes.append("displayData")
        }
        if self.alertData != other.alertData {
            changes.append("alertData")
        }
        if self.connectionData != other.connectionData {
            changes.append("connectionData")
        }
        if self.lastUpdated != other.lastUpdated {
            changes.append("lastUpdated")
        }

        return changes.isEmpty ? "no changes" : changes.joined(separator: ", ")
    }
}
// swiftlint:enable file_length
