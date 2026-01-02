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

    @Published var latestRawRecord: RuuviTagSensorRecord?

    // MARK: - Published Properties
    @Published var displayData: RuuviTagCardSnapshotDisplayData
    @Published var metadata: RuuviTagCardSnapshotMetadata
    @Published var alertData: RuuviTagCardSnapshotAlertData
    @Published var connectionData: RuuviTagCardSnapshotConnectionData
    @Published var ownership: RuuviTagCardSnapshotOwnership
    @Published var calibration: RuuviTagCardSnapshotCalibrationData
    @Published var capabilities: RuuviTagCardSnapshotCapabilities
    @Published var lastUpdated: Date?

    public var anyIndicatorAlertPublisher: AnyPublisher<[RuuviTagCardSnapshotAlertConfig], Never> {
        return $displayData
            .map { displayData -> [RuuviTagCardSnapshotAlertConfig] in
                return displayData.indicatorGrid?.indicators.compactMap { indicator in
                    self.alertConfig(for: indicator)
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
        // Check luid
        let luidMatches: Bool? = {
            guard let lhsLuid = lhs.luid, let rhsLuid = rhs.luid else {
                return nil // Both nil or one nil = no match
            }
            return lhsLuid.any == rhsLuid.any
        }()

        // Check mac
        let macMatches: Bool? = {
            guard let lhsMac = lhs.mac, let rhsMac = rhs.mac else {
                return nil // Both nil or one nil = no match
            }
            return lhsMac.any == rhsMac.any
        }()

        // At least one identifier must match and be non-nil
        return luidMatches == true || macMatches == true
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
    var measurementVisibility: RuuviTagCardSnapshotMeasurementVisibility?
    var hasNoData: Bool = false
    var networkSyncStatus: NetworkSyncStatus = .none
    var voltage: Double?
    var accelerationX: Double?
    var accelerationY: Double?
    var accelerationZ: Double?
    var txPower: Int?
    var measurementSequenceNumber: Int?
    var latestRSSI: Int?

    var primaryIndicator: RuuviTagCardSnapshotIndicatorData? {
        indicatorGrid?.primaryIndicator
    }

    var secondaryIndicators: [RuuviTagCardSnapshotIndicatorData] {
        indicatorGrid?.secondaryIndicators ?? []
    }

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
        lhs.measurementVisibility == rhs.measurementVisibility &&
        lhs.hasNoData == rhs.hasNoData &&
        lhs.networkSyncStatus == rhs.networkSyncStatus &&
        lhs.firmwareVersion == rhs.firmwareVersion &&
        lhs.voltage == rhs.voltage &&
        lhs.accelerationX == rhs.accelerationX &&
        lhs.accelerationY == rhs.accelerationY &&
        lhs.accelerationZ == rhs.accelerationZ &&
        lhs.txPower == rhs.txPower &&
        lhs.measurementSequenceNumber == rhs.measurementSequenceNumber &&
        lhs.latestRSSI == rhs.latestRSSI
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

// swiftlint:disable:next type_name
struct RuuviTagCardSnapshotMeasurementVisibility: Equatable {
    var usesDefaultOrder: Bool = true
    var availableVariants: [MeasurementDisplayVariant] = []
    var visibleVariants: [MeasurementDisplayVariant] = []
    var hiddenVariants: [MeasurementDisplayVariant] = []

    var availableIndicatorCount: Int {
        availableVariants.count
    }

    var visibleIndicatorCount: Int {
        visibleVariants.count
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
    var isPushNotificationsEnabled: Bool = true
    var isPushNotificationsAvailable: Bool = true
    var isCloudAlertsAvailable: Bool = false
    var isCloudConnectionAlertsAvailable: Bool = false
}

struct RuuviTagCardSnapshotCalibrationData: Equatable {
    // Formatted offset strings
    var temperatureOffset: String?
    var humidityOffset: String?
    var pressureOffset: String?

    var isHumidityOffsetVisible: Bool = false
    var isPressureOffsetVisible: Bool = false
}

// MARK: - Alert Data Structures
struct RuuviTagCardSnapshotAlertData: Equatable {
    var alertState: AlertState?
    var hasActiveAlerts: Bool = false
    var alertConfigurations: [String: RuuviTagCardSnapshotAlertConfig] = [:]
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

    var primaryIndicator: RuuviTagCardSnapshotIndicatorData? {
        indicators.first
    }

    var secondaryIndicators: [RuuviTagCardSnapshotIndicatorData] {
        guard indicators.count > 1 else { return [] }
        return Array(indicators.dropFirst())
    }
}

struct RuuviTagCardSnapshotIndicatorData: Equatable, Hashable {
    let variant: MeasurementDisplayVariant
    var type: MeasurementType { variant.type }
    let value: String
    let unit: String
    let isProminent: Bool
    let showSubscript: Bool
    let tintColor: UIColor?
    let qualityState: MeasurementQualityState?

    func hash(into hasher: inout Hasher) {
        hasher.combine(variant)
    }
}

// MARK: - Alert Access Methods
extension RuuviTagCardSnapshot {

    // MARK: - Alert Configuration Access
    private func isNonMeasurementAlertType(_ alertType: AlertType) -> Bool {
        switch alertType {
        case .connection, .cloudConnection, .movement:
            return true
        default:
            return false
        }
    }

    private func alertKey(for alertType: AlertType) -> String {
        alertType.rawValue
    }

    private func normalizedAlertType(_ alertType: AlertType) -> AlertType {
        AlertType.alertType(from: alertType.rawValue) ?? alertType
    }

    private func alertConfig(
        for indicator: RuuviTagCardSnapshotIndicatorData
    ) -> RuuviTagCardSnapshotAlertConfig? {
        if let alertType = indicator.variant.toAlertType() {
            return getAlertConfig(for: alertType)
        }
        return getAlertConfig(for: indicator.type)
    }

    private func storeAlertConfig(
        for alertType: AlertType,
        config: RuuviTagCardSnapshotAlertConfig
    ) {
        if isNonMeasurementAlertType(alertType) {
            alertData.nonMeasurementAlerts[normalizedAlertType(alertType)] = config
        } else {
            alertData.alertConfigurations[alertKey(for: alertType)] = config
        }
    }

    func getAlertConfig(for measurementType: MeasurementType) -> RuuviTagCardSnapshotAlertConfig? {
        guard let alertType = measurementType.toAlertType() else { return nil }
        return getAlertConfig(for: alertType)
    }

    func getAlertConfig(for alertType: AlertType) -> RuuviTagCardSnapshotAlertConfig? {
        if isNonMeasurementAlertType(alertType) {
            return alertData.nonMeasurementAlerts[normalizedAlertType(alertType)]
        }

        guard let config = alertData.alertConfigurations[alertKey(for: alertType)] else {
            return nil
        }
        if let storedType = config.alertType,
           storedType.rawValue != alertType.rawValue {
            return nil
        }
        return config
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
        return alertConfig(for: indicator) ?? .inactive
    }

    func isIndicatorHighlighted(for indicator: RuuviTagCardSnapshotIndicatorData) -> Bool {
        return getIndicatorAlertConfig(for: indicator).isHighlighted
    }

    // MARK: - Alert Configuration Updates
    func updateAlertConfig(
        for measurementType: MeasurementType,
        config: RuuviTagCardSnapshotAlertConfig
    ) {
        guard let alertType = measurementType.toAlertType() else { return }
        updateAlertConfig(for: alertType, config: config)
    }

    func updateAlertConfig(
        for alertType: AlertType,
        config: RuuviTagCardSnapshotAlertConfig
    ) {
        storeAlertConfig(for: alertType, config: config)
        updateOverallAlertState()
    }

    func removeAlertConfig(for measurementType: MeasurementType) {
        guard let alertType = measurementType.toAlertType() else { return }
        removeAlertConfig(for: alertType)
    }

    func removeAlertConfig(for alertType: AlertType) {
        if isNonMeasurementAlertType(alertType) {
            alertData.nonMeasurementAlerts.removeValue(forKey: normalizedAlertType(alertType))
        } else {
            alertData.alertConfigurations.removeValue(forKey: alertKey(for: alertType))
        }
        updateOverallAlertState()
    }
}

// MARK: - Snapshot Update Methods
extension RuuviTagCardSnapshot {

    // MARK: - Update Metadata
    @discardableResult
    func updateMetadata(
        isConnected: Bool? = nil,
        serviceUUID: String? = nil,
        isCloud: Bool? = nil,
        isOwner: Bool? = nil,
        isConnectable: Bool? = nil,
        canShareTag: Bool? = nil
    ) -> Bool {
        var didChange = false

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
            didChange = true
        }

        // Update other metadata properties if provided
        if let isCloud = isCloud, self.metadata.isCloud != isCloud {
            self.metadata.isCloud = isCloud
            didChange = true
        }

        if let isOwner = isOwner, self.metadata.isOwner != isOwner {
            self.metadata.isOwner = isOwner
            didChange = true
        }

        let currentIsConnectable = isConnectable ?? self.connectionData.isConnectable
        let newIsChartAvailable = currentIsConnectable ||
                                  currentServiceUUID != nil ||
                                  currentIsCloud
        if self.metadata.isChartAvailable != newIsChartAvailable {
            self.metadata.isChartAvailable = newIsChartAvailable
            didChange = true
        }

        if let canShareTag = canShareTag,
           self.metadata.canShareTag != canShareTag {
            self.metadata.canShareTag = canShareTag
            didChange = true
        }

        return didChange
    }

    @discardableResult
    func updateMeasurementVisibility(
        _ visibility: RuuviTagCardSnapshotMeasurementVisibility?
    ) -> Bool {
        guard displayData.measurementVisibility != visibility else {
            return false
        }
        displayData.measurementVisibility = visibility
        return true
    }

    // MARK: - Update Connection Data
    @discardableResult
    func updateConnectionData(
        isConnected: Bool,
        isConnectable: Bool,
        keepConnection: Bool
    ) -> Bool {
        let newConnectionData = RuuviTagCardSnapshotConnectionData(
            isConnected: isConnected,
            isConnectable: isConnectable,
            keepConnection: keepConnection
        )

        // Only update if connection data actually changed
        guard self.connectionData != newConnectionData else { return false }

        self.connectionData = newConnectionData

        var didChange = true

        // Update metadata when connection data changes
        if updateMetadata(isConnected: isConnected, isConnectable: isConnectable) {
            didChange = true
        }

        let alertsEnabled =
            metadata.isCloud ||
            self.connectionData.isConnected ||
            identifierData.serviceUUID != nil

        if capabilities.isAlertsEnabled != alertsEnabled {
            capabilities.isAlertsEnabled = alertsEnabled
            didChange = true
        }

        return didChange
    }

    // MARK: - Update Background Image
    @discardableResult
    func updateBackgroundImage(_ image: UIImage?) -> Bool {
        // Only update if image actually changed
        guard self.displayData.background !== image else { return false }

        self.displayData.background = image
        return true
    }

    // MARK: - Update Network Sync Status
    @discardableResult
    func updateNetworkSyncStatus(_ status: NetworkSyncStatus) -> Bool {
        // Only update if status actually changed
        guard self.displayData.networkSyncStatus != status else { return false }

        self.displayData.networkSyncStatus = status
        return true
    }

    // MARK: - Legacy Alert Update Method (for backward compatibility)
    func updateAlert(
        for type: MeasurementType,
        isOn: Bool,
        alertState: AlertState?,
        mutedTill: Date?
    ) {
        guard let alertType = type.toAlertType() else { return }
        let config = RuuviTagCardSnapshotAlertConfig(
            type: type,
            alertType: alertType,
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
        alertData.alertConfigurations.removeAll()
        alertData.nonMeasurementAlerts.removeAll()

        // Sync measurement-based alerts
        let profile = RuuviTagDataService.measurementDisplayProfile(for: self)
        let alertVariants = profile.entries(for: .alert).map(\.variant)
        var syncedAlertTypes: Set<String> = []

        for variant in alertVariants {
            guard let alertType = variant.toAlertType() else { continue }
            guard syncedAlertTypes.insert(alertType.rawValue).inserted else { continue }
            let isOn = alertService.isOn(type: alertType, for: physicalSensor)
            let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

            let config = RuuviTagCardSnapshotAlertConfig(
                type: variant.type,
                alertType: alertType,
                isActive: isOn,
                isFiring: false, // Will be updated by alert handler
                mutedTill: mutedTill
            )

            storeAlertConfig(for: alertType, config: config)
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

            storeAlertConfig(for: alertType, config: config)
        }

        updateOverallAlertState()
    }

    // MARK: - Update from RuuviTagSensorRecord
    @discardableResult
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func updateFromRecord(
        _ record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        sensorSettings: SensorSettings? = nil
    ) -> Bool {
        // Apply sensor settings to record if available
        let finalRecord = sensorSettings != nil ? record.with(sensorSettings: sensorSettings) : record

        let recordChanged = latestRawRecord?.date != finalRecord.date
        latestRawRecord = finalRecord

        var updatedDisplayData = displayData
        var didChange = recordChanged

        if recordChanged {
            updatedDisplayData.source = finalRecord.source
            updatedDisplayData.hasNoData = false

            let batteryStatusProvider = RuuviTagBatteryStatusProvider()
            updatedDisplayData.batteryNeedsReplacement = batteryStatusProvider.batteryNeedsReplacement(
                temperature: finalRecord.temperature,
                voltage: finalRecord.voltage
            )

            updatedDisplayData.indicatorGrid = RuuviTagCardSnapshotDataBuilder.createIndicatorGrid(
                from: finalRecord,
                sensor: sensor,
                measurementService: measurementService,
                flags: flags,
                snapshot: self
            )
        }

        if updatedDisplayData.name != sensor.name || updatedDisplayData.version != sensor.version {
            updatedDisplayData.name = sensor.name
            updatedDisplayData.version = sensor.version
        }

        let resolvedFirmware =
            sensor.displayFirmwareVersion ?? sensor.firmwareVersion
        if updatedDisplayData.firmwareVersion != resolvedFirmware {
            updatedDisplayData.firmwareVersion = resolvedFirmware
        }

        if updatedDisplayData.voltage != finalRecord.voltage?.value {
            updatedDisplayData.voltage = finalRecord.voltage?.value
        }
        let accX = finalRecord.acceleration?.x.value
        if updatedDisplayData.accelerationX != accX {
            updatedDisplayData.accelerationX = accX
        }
        let accY = finalRecord.acceleration?.y.value
        if updatedDisplayData.accelerationY != accY {
            updatedDisplayData.accelerationY = accY
        }
        let accZ = finalRecord.acceleration?.z.value
        if updatedDisplayData.accelerationZ != accZ {
            updatedDisplayData.accelerationZ = accZ
        }
        if updatedDisplayData.txPower != finalRecord.txPower {
            updatedDisplayData.txPower = finalRecord.txPower
        }
        if updatedDisplayData.measurementSequenceNumber != finalRecord.measurementSequenceNumber {
            updatedDisplayData.measurementSequenceNumber = finalRecord.measurementSequenceNumber
        }
        if updatedDisplayData.latestRSSI != finalRecord.rssi {
            updatedDisplayData.latestRSSI = finalRecord.rssi
        }

        if updatedDisplayData != displayData {
            displayData = updatedDisplayData
            didChange = true
        }

        var updatedCalibration = calibration
        if let sensorSettings {
            updatedCalibration.temperatureOffset = measurementService?
                .temperatureOffsetCorrectionString(for: sensorSettings.temperatureOffset ?? 0)
            updatedCalibration.humidityOffset = measurementService?
                .humidityOffsetCorrectionString(for: sensorSettings.humidityOffset ?? 0)
            updatedCalibration.pressureOffset = measurementService?
                .pressureOffsetCorrectionString(for: sensorSettings.pressureOffset ?? 0)
        }
        updatedCalibration.isHumidityOffsetVisible = finalRecord.humidity != nil
        updatedCalibration.isPressureOffsetVisible = finalRecord.pressure != nil

        if updatedCalibration != calibration {
            calibration = updatedCalibration
            didChange = true
        }

        if lastUpdated != finalRecord.date {
            lastUpdated = finalRecord.date
            didChange = true
        }

        return didChange
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
            lastUpdated: nil
        )
    }
}

// swiftlint:enable file_length
