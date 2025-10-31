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
    @Published var ownership: RuuviTagCardSnapshotOwnership
    @Published var calibration: RuuviTagCardSnapshotCalibrationData
    @Published var capabilities: RuuviTagCardSnapshotCapabilities
    @Published var diagnostics: RuuviTagCardSnapshotDiagnosticsData
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
        ownership: RuuviTagCardSnapshotOwnership = RuuviTagCardSnapshotOwnership(),
        calibration: RuuviTagCardSnapshotCalibrationData = RuuviTagCardSnapshotCalibrationData(),
        capabilities: RuuviTagCardSnapshotCapabilities = RuuviTagCardSnapshotCapabilities(),
        diagnostics: RuuviTagCardSnapshotDiagnosticsData = RuuviTagCardSnapshotDiagnosticsData(),
        lastUpdated: Date?
    ) {
        self.id = id
        self.identifierData = identifierData
        self.displayData = displayData
        self.alertData = alertData
        self.connectionData = connectionData
        self.lastUpdated = lastUpdated
        self.metadata = metadata
        self.ownership = ownership
        self.calibration = calibration
        self.capabilities = capabilities
        self.diagnostics = diagnostics
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
        lhs.ownership == rhs.ownership &&
        lhs.calibration == rhs.calibration &&
        lhs.capabilities == rhs.capabilities &&
        lhs.diagnostics == rhs.diagnostics &&
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
    var firmwareVersion: String?
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
        lhs.networkSyncStatus == rhs.networkSyncStatus &&
        lhs.firmwareVersion == rhs.firmwareVersion
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

struct RuuviTagCardSnapshotOwnership: Equatable {
    var ownerName: String?
    var ownersPlan: String?
    var sharedTo: [String] = []
    var maxShareCount: Int?
    var isAuthorized: Bool = false
    var isClaimedTag: Bool = false
    var canClaimTag: Bool = false
    var isOwnersPlanProPlus: Bool = false
}

struct RuuviTagCardSnapshotCapabilities: Equatable {
    var showKeepConnection: Bool = false
    var showBatteryStatus: Bool = false
    var hideSwitchStatusLabel: Bool = false
    var isAlertsEnabled: Bool = false
    var isPushNotificationsEnabled: Bool = false
    var isPushNotificationsAvailable: Bool = false
    var isCloudAlertsAvailable: Bool = false
    var isCloudConnectionAlertsAvailable: Bool = false
}

struct RuuviTagCardSnapshotCalibrationData: Equatable {
    var temperatureOffset: Double?
    var humidityOffset: Double?
    var pressureOffset: Double?
    var isHumidityOffsetVisible: Bool = false
    var isPressureOffsetVisible: Bool = false
}

struct RuuviTagCardSnapshotDiagnosticsData: Equatable {
    var voltage: Double?
    var accelerationX: Double?
    var accelerationY: Double?
    var accelerationZ: Double?
    var txPower: Int?
    var measurementSequenceNumber: Int?
    var movementCounter: Int?
    var latestRSSI: Int?
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
        isConnectable: Bool? = nil,
        canShareTag: Bool? = nil
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

        if let canShareTag = canShareTag,
           self.metadata.canShareTag != canShareTag {
            self.metadata.canShareTag = canShareTag
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

        capabilities.isAlertsEnabled =
            metadata.isCloud ||
            self.connectionData.isConnected ||
            identifierData.serviceUUID != nil
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

        let resolvedFirmware =
            sensor.displayFirmwareVersion ?? sensor.firmwareVersion
        if self.displayData.firmwareVersion != resolvedFirmware {
            self.displayData.firmwareVersion = resolvedFirmware
        }

        diagnostics.voltage = finalRecord.voltage?.value
        diagnostics.accelerationX = finalRecord.acceleration?.x.value
        diagnostics.accelerationY = finalRecord.acceleration?.y.value
        diagnostics.accelerationZ = finalRecord.acceleration?.z.value
        diagnostics.txPower = finalRecord.txPower
        diagnostics.measurementSequenceNumber = finalRecord.measurementSequenceNumber
        diagnostics.movementCounter = finalRecord.movementCounter
        diagnostics.latestRSSI = finalRecord.rssi

        calibration.temperatureOffset = sensorSettings?.temperatureOffset
        calibration.humidityOffset = sensorSettings?.humidityOffset
        calibration.pressureOffset = sensorSettings?.pressureOffset
        calibration.isHumidityOffsetVisible = finalRecord.humidity != nil
        calibration.isPressureOffsetVisible = finalRecord.pressure != nil

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
        let ownership = RuuviTagCardSnapshotOwnership()
        let calibration = RuuviTagCardSnapshotCalibrationData()
        let capabilities = RuuviTagCardSnapshotCapabilities()
        let diagnostics = RuuviTagCardSnapshotDiagnosticsData()

        return RuuviTagCardSnapshot(
            id: id,
            identifierData: identifierData,
            displayData: displayData,
            metadata: metadata,
            alertData: alertData,
            connectionData: connectionData,
            ownership: ownership,
            calibration: calibration,
            capabilities: capabilities,
            diagnostics: diagnostics,
            lastUpdated: nil
        )
    }
}

// swiftlint:enable file_length
