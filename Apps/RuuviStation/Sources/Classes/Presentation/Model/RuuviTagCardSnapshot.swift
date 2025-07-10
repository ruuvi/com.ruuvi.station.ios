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

struct RuuviTagCardSnapshotAlertData: Equatable {
    var alertState: AlertState?
    var hasActiveAlerts: Bool = false

    static func == (
        lhs: RuuviTagCardSnapshotAlertData,
        rhs: RuuviTagCardSnapshotAlertData
    ) -> Bool {
        return lhs.alertState == rhs.alertState &&
        lhs.hasActiveAlerts == rhs.hasActiveAlerts
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
    let alertConfig: RuuviTagCardSnapshotAlertConfig

    let isProminent: Bool
    let showSubscript: Bool
    let tintColor: UIColor?

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }

    var isHighlighted: Bool {
        return alertConfig.isHighlighted
    }
}

struct RuuviTagCardSnapshotAlertConfig: Equatable {
    let isActive: Bool
    let isFiring: Bool
    let mutedTill: Date?

    static let inactive = RuuviTagCardSnapshotAlertConfig(
        isActive: false,
        isFiring: false,
        mutedTill: nil
    )

    var isHighlighted: Bool {
        return isActive && isFiring
    }
}

// MARK: - Snapshot Update Methods
extension RuuviTagCardSnapshot {

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

    // MARK: - Update Alert for Specific Measurement Type
    func updateAlert(
        for type: MeasurementType,
        isOn: Bool,
        alertState: AlertState?,
        mutedTill: Date?
    ) {
        guard let currentGrid = self.displayData.indicatorGrid else { return }

        // Check if any indicator actually needs updating
        var hasChanges = false
        let updatedIndicators = currentGrid.indicators.map { indicator -> RuuviTagCardSnapshotIndicatorData in
            if indicator.type == type {
                let newAlertConfig = RuuviTagCardSnapshotAlertConfig(
                    isActive: isOn,
                    isFiring: alertState == .firing,
                    mutedTill: mutedTill
                )

                // Only mark as changed if the alert config actually changed
                if indicator.alertConfig != newAlertConfig {
                    hasChanges = true
                }

                return RuuviTagCardSnapshotIndicatorData(
                    type: indicator.type,
                    value: indicator.value,
                    unit: indicator.unit,
                    alertConfig: newAlertConfig,
                    isProminent: indicator.isProminent,
                    showSubscript: indicator.showSubscript,
                    tintColor: indicator.tintColor
                )
            } else {
                return indicator
            }
        }

        // Only update if there are actual changes
        guard hasChanges else { return }

        // Update the grid
        self.displayData.indicatorGrid = RuuviTagCardSnapshotIndicatorGridConfiguration(
            indicators: updatedIndicators
        )

        // Update overall alert state
        updateOverallAlertState()
    }

    // MARK: - Update Overall Alert State
    private func updateOverallAlertState() {
        guard let indicators = self.displayData.indicatorGrid?.indicators else {
            // Only update if current state is different
            let newAlertState: AlertState = .empty
            let newHasActiveAlerts = false

            if self.alertData.alertState != newAlertState ||
               self.alertData.hasActiveAlerts != newHasActiveAlerts {
                self.alertData.alertState = newAlertState
                self.alertData.hasActiveAlerts = newHasActiveAlerts
            }
            return
        }

        // Calculate new state
        let hasFiringAlert = indicators.contains { $0.alertConfig.isFiring }
        let hasActiveAlert = indicators.contains { $0.alertConfig.isActive }

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
        guard let currentGrid = self.displayData.indicatorGrid else { return }

        var hasChanges = false
        let updatedIndicators = currentGrid.indicators.map { indicator -> RuuviTagCardSnapshotIndicatorData in
            let alertType = indicator.type.toAlertType()
            let isOn = alertService.isOn(type: alertType, for: physicalSensor)
            let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

            let newAlertConfig = RuuviTagCardSnapshotAlertConfig(
                isActive: isOn,
                isFiring: false, // Will be updated by alert handler when alerts fire
                mutedTill: mutedTill
            )

            // Check if this indicator's alert config changed
            if indicator.alertConfig != newAlertConfig {
                hasChanges = true
            }

            return RuuviTagCardSnapshotIndicatorData(
                type: indicator.type,
                value: indicator.value,
                unit: indicator.unit,
                alertConfig: newAlertConfig,
                isProminent: indicator.isProminent,
                showSubscript: indicator.showSubscript,
                tintColor: indicator.tintColor
            )
        }

        // Only update if there are actual changes
        guard hasChanges else { return }

        // Update the grid
        self.displayData.indicatorGrid = RuuviTagCardSnapshotIndicatorGridConfiguration(
            indicators: updatedIndicators
        )

        // Update overall state
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
                alertData: self.alertData
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
        isCloud: Bool,
        isOwner: Bool,
        isConnectable: Bool,
        version: Int?
    ) -> RuuviTagCardSnapshot {

        let identifierData = RuuviTagCardSnapshotIdentityData(
            luid: luid,
            mac: mac,
            serviceUUID: nil
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
            isChartAvailable: isConnectable,
            isAlertAvailable: true,
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
