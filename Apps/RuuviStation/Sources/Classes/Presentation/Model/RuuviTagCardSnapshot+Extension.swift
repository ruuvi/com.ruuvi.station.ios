import Foundation
import RuuviOntology

// MARK: - Alert Settings Structure
struct RuuviTagCardSnapshotAlertSettings {
    var isOn: Bool = false
    var mutedTill: Date?
    var lowerBound: Double?
    var upperBound: Double?
    var description: String?
    var unseenDuration: Double?
}

// MARK: - Alert Management Extensions
extension RuuviTagCardSnapshot {

    // MARK: - Alert Settings Access
    func getAlertSettings(for measurementType: MeasurementType) -> RuuviTagCardSnapshotAlertSettings? {
        guard let config = getAlertConfig(for: measurementType) else { return nil }

        return RuuviTagCardSnapshotAlertSettings(
            isOn: config.isActive,
            mutedTill: config.mutedTill,
            lowerBound: config.lowerBound,
            upperBound: config.upperBound,
            description: config.description,
            unseenDuration: config.unseenDuration
        )
    }

    func getAlertSettings(for alertType: AlertType) -> RuuviTagCardSnapshotAlertSettings? {
        guard let config = getAlertConfig(for: alertType) else { return nil }

        return RuuviTagCardSnapshotAlertSettings(
            isOn: config.isActive,
            mutedTill: config.mutedTill,
            lowerBound: config.lowerBound,
            upperBound: config.upperBound,
            description: config.description,
            unseenDuration: config.unseenDuration
        )
    }

    // MARK: - Alert Settings Updates
    func updateAlertSettings(
        for measurementType: MeasurementType,
        settings: RuuviTagCardSnapshotAlertSettings
    ) {
        let currentConfig = getAlertConfig(for: measurementType)
        guard let alertType = currentConfig?.alertType ?? measurementType.toAlertType() else {
            return
        }

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: measurementType,
            alertType: alertType,
            isActive: settings.isOn,
            isFiring: currentConfig?.isFiring ?? false,
            mutedTill: settings.mutedTill,
            lowerBound: settings.lowerBound,
            upperBound: settings.upperBound,
            description: settings.description,
            unseenDuration: settings.unseenDuration
        )

        updateAlertConfig(for: measurementType, config: updatedConfig)
    }

    func updateAlertSettings(
        for alertType: AlertType,
        settings: RuuviTagCardSnapshotAlertSettings
    ) {
        let currentConfig = getAlertConfig(for: alertType)

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: alertType.toMeasurementType(),
            alertType: alertType,
            isActive: settings.isOn,
            isFiring: currentConfig?.isFiring ?? false,
            mutedTill: settings.mutedTill,
            lowerBound: settings.lowerBound,
            upperBound: settings.upperBound,
            description: settings.description,
            unseenDuration: settings.unseenDuration
        )

        updateAlertConfig(for: alertType, config: updatedConfig)
    }

    // MARK: - Individual Alert Property Updates
    func updateAlertMutedTill(
        for measurementType: MeasurementType,
        mutedTill: Date?
    ) {
        guard let currentConfig = getAlertConfig(for: measurementType) else { return }

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: mutedTill,
            lowerBound: currentConfig.lowerBound,
            upperBound: currentConfig.upperBound,
            description: currentConfig.description,
            unseenDuration: currentConfig.unseenDuration
        )

        updateAlertConfig(for: measurementType, config: updatedConfig)
    }

    func updateAlertMutedTill(
        for alertType: AlertType,
        mutedTill: Date?
    ) {
        guard let currentConfig = getAlertConfig(for: alertType) else { return }

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: mutedTill,
            lowerBound: currentConfig.lowerBound,
            upperBound: currentConfig.upperBound,
            description: currentConfig.description,
            unseenDuration: currentConfig.unseenDuration
        )

        updateAlertConfig(for: alertType, config: updatedConfig)
    }

    func updateAlertDescription(
        for measurementType: MeasurementType,
        description: String?
    ) {
        guard let currentConfig = getAlertConfig(for: measurementType) else { return }

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

        updateAlertConfig(for: measurementType, config: updatedConfig)
    }

    func updateAlertDescription(
        for alertType: AlertType,
        description: String?
    ) {
        guard let currentConfig = getAlertConfig(for: alertType) else { return }

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

        updateAlertConfig(for: alertType, config: updatedConfig)
    }

    func updateAlertBounds(
        for measurementType: MeasurementType,
        lowerBound: Double? = nil,
        upperBound: Double? = nil
    ) {
        guard let currentConfig = getAlertConfig(for: measurementType) else { return }

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: currentConfig.mutedTill,
            lowerBound: lowerBound ?? currentConfig.lowerBound,
            upperBound: upperBound ?? currentConfig.upperBound,
            description: currentConfig.description,
            unseenDuration: currentConfig.unseenDuration
        )

        updateAlertConfig(for: measurementType, config: updatedConfig)
    }

    func updateAlertBounds(
        for alertType: AlertType,
        lowerBound: Double? = nil,
        upperBound: Double? = nil
    ) {
        guard let currentConfig = getAlertConfig(for: alertType) else { return }

        let updatedConfig = RuuviTagCardSnapshotAlertConfig(
            type: currentConfig.type,
            alertType: currentConfig.alertType,
            isActive: currentConfig.isActive,
            isFiring: currentConfig.isFiring,
            mutedTill: currentConfig.mutedTill,
            lowerBound: lowerBound ?? currentConfig.lowerBound,
            upperBound: upperBound ?? currentConfig.upperBound,
            description: currentConfig.description,
            unseenDuration: currentConfig.unseenDuration
        )

        updateAlertConfig(for: alertType, config: updatedConfig)
    }

    // MARK: - Alert State Queries
    func hasAnyActiveAlerts() -> Bool {
        return !getAllActiveAlerts().isEmpty
    }

    func hasAnyFiringAlerts() -> Bool {
        return !getAllFiringAlerts().isEmpty
    }

    func getActiveAlertsCount() -> Int {
        return getAllActiveAlerts().count
    }

    func getFiringAlertsCount() -> Int {
        return getAllFiringAlerts().count
    }

    func getMutedAlertsCount() -> Int {
        let currentDate = Date()
        let measurementMutedCount = alertData.alertConfigurations.values.filter { config in
            config.isActive && config.mutedTill != nil && config.mutedTill! > currentDate
        }.count

        let nonMeasurementMutedCount = alertData.nonMeasurementAlerts.values.filter { config in
            config.isActive && config.mutedTill != nil && config.mutedTill! > currentDate
        }.count

        return measurementMutedCount + nonMeasurementMutedCount
    }

    // MARK: - Alert Summary (DEBUG)
    func getAlertSummary() -> String {
        let activeCount = getActiveAlertsCount()
        let firingCount = getFiringAlertsCount()
        let mutedCount = getMutedAlertsCount()

        var summary = "Alerts: \(activeCount) active"
        if firingCount > 0 {
            summary += ", \(firingCount) firing"
        }
        if mutedCount > 0 {
            summary += ", \(mutedCount) muted"
        }

        return summary
    }
}
