import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology

extension RuuviCloudApiSetting {
    var key: String {
        rawValue
    }

    func userSetting(
        from localSettings: RuuviLocalSettings,
        lastUpdated: Date? = nil
    ) -> RuuviUserSetting? {
        guard let value = localValue(from: localSettings) else {
            return nil
        }
        return RuuviUserSettingStruct(
            key: key,
            value: value,
            lastUpdated: lastUpdated
        )
    }

    func missingCloudUserSetting(
        from localSettings: RuuviLocalSettings,
        lastUpdated: Date? = nil
    ) -> RuuviUserSetting? {
        guard let value = missingCloudValue(from: localSettings) else {
            return nil
        }
        return RuuviUserSettingStruct(
            key: key,
            value: value,
            lastUpdated: lastUpdated
        )
    }

    func localValue(from settings: RuuviLocalSettings) -> String? {
        switch self {
        case .unitTemperature, .accuracyTemperature, .unitHumidity, .accuracyHumidity,
             .unitPressure, .accuracyPressure:
            measurementLocalValue(from: settings)
        case .chartShowAllPoints, .chartDrawDots, .chartShowMinMaxAverage:
            chartLocalValue(from: settings)
        case .cloudModeEnabled, .dashboardEnabled, .dashboardType, .dashboardTapActionType:
            dashboardLocalValue(from: settings)
        case .emailAlertDisabled, .pushAlertDisabled, .marketingPreference,
             .profileLanguageCode, .dashboardSensorOrder:
            accountLocalValue(from: settings)
        default:
            nil
        }
    }

    @discardableResult
    func apply(
        userSetting: RuuviUserSetting,
        to localSettings: RuuviLocalSettings
    ) -> Bool {
        guard userSetting.key == key else {
            return false
        }
        return apply(value: userSetting.value, to: localSettings)
    }

    @discardableResult
    func apply(value: String, to settings: RuuviLocalSettings) -> Bool {
        switch self {
        case .unitTemperature, .accuracyTemperature, .unitHumidity, .accuracyHumidity,
             .unitPressure, .accuracyPressure:
            return applyMeasurementValue(value, to: settings)
        case .chartShowAllPoints, .chartDrawDots, .chartShowMinMaxAverage:
            return applyChartValue(value, to: settings)
        case .cloudModeEnabled, .dashboardEnabled, .dashboardType, .dashboardTapActionType:
            return applyDashboardValue(value, to: settings)
        case .emailAlertDisabled, .pushAlertDisabled, .marketingPreference,
             .profileLanguageCode, .dashboardSensorOrder:
            return applyAccountValue(value, to: settings)
        default:
            return false
        }
    }

    @discardableResult
    func applyMissingCloudValue(to settings: RuuviLocalSettings) -> Bool {
        guard let value = missingCloudValue(from: settings) else {
            return false
        }
        return apply(value: value, to: settings)
    }

    private func missingCloudValue(from settings: RuuviLocalSettings) -> String? {
        switch self {
        case .profileLanguageCode:
            settings.language.rawValue
        default:
            nil
        }
    }

    private func measurementLocalValue(from settings: RuuviLocalSettings) -> String {
        switch self {
        case .unitTemperature:
            settings.temperatureUnit.ruuviCloudApiSettingString
        case .accuracyTemperature:
            settings.temperatureAccuracy.value.ruuviCloudApiSettingString
        case .unitHumidity:
            settings.humidityUnit.ruuviCloudApiSettingString
        case .accuracyHumidity:
            settings.humidityAccuracy.value.ruuviCloudApiSettingString
        case .unitPressure:
            settings.pressureUnit.ruuviCloudApiSettingString
        case .accuracyPressure:
            settings.pressureAccuracy.value.ruuviCloudApiSettingString
        default:
            preconditionFailure("Unexpected measurement setting")
        }
    }

    private func chartLocalValue(from settings: RuuviLocalSettings) -> String {
        switch self {
        case .chartShowAllPoints:
            (!settings.chartDownsamplingOn).chartBoolSettingString
        case .chartDrawDots:
            settings.chartDrawDotsOn.chartBoolSettingString
        case .chartShowMinMaxAverage:
            settings.chartStatsOn.chartBoolSettingString
        default:
            preconditionFailure("Unexpected chart setting")
        }
    }

    private func dashboardLocalValue(from settings: RuuviLocalSettings) -> String {
        switch self {
        case .cloudModeEnabled:
            settings.cloudModeEnabled.chartBoolSettingString
        case .dashboardEnabled:
            settings.dashboardEnabled.chartBoolSettingString
        case .dashboardType:
            settings.dashboardType.rawValue
        case .dashboardTapActionType:
            settings.dashboardTapActionType.rawValue
        default:
            preconditionFailure("Unexpected dashboard setting")
        }
    }

    private func accountLocalValue(from settings: RuuviLocalSettings) -> String? {
        switch self {
        case .emailAlertDisabled:
            settings.emailAlertDisabled.chartBoolSettingString
        case .pushAlertDisabled:
            settings.pushAlertDisabled.chartBoolSettingString
        case .marketingPreference:
            settings.marketingPreference.chartBoolSettingString
        case .profileLanguageCode:
            settings.cloudProfileLanguageCode ?? settings.language.rawValue
        case .dashboardSensorOrder:
            RuuviCloudApiHelper.jsonStringFromArray(settings.dashboardSensorOrder)
        default:
            preconditionFailure("Unexpected account setting")
        }
    }

    private func applyMeasurementValue(
        _ value: String,
        to settings: RuuviLocalSettings
    ) -> Bool {
        switch self {
        case .unitTemperature:
            guard let value = value.ruuviCloudApiSettingUnitTemperature else { return false }
            return update(settings.temperatureUnit, value) {
                settings.temperatureUnit = $0
            }
        case .accuracyTemperature:
            guard let value = value.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional else { return false }
            return update(settings.temperatureAccuracy, value) {
                settings.temperatureAccuracy = $0
            }
        case .unitHumidity:
            guard let value = value.ruuviCloudApiSettingUnitHumidity else { return false }
            return update(settings.humidityUnit, value) {
                settings.humidityUnit = $0
            }
        case .accuracyHumidity:
            guard let value = value.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional else { return false }
            return update(settings.humidityAccuracy, value) {
                settings.humidityAccuracy = $0
            }
        case .unitPressure:
            guard let value = value.ruuviCloudApiSettingUnitPressure else { return false }
            return update(settings.pressureUnit, value) {
                settings.pressureUnit = $0
            }
        case .accuracyPressure:
            guard let value = value.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional else { return false }
            return update(settings.pressureAccuracy, value) {
                settings.pressureAccuracy = $0
            }
        default:
            preconditionFailure("Unexpected measurement setting")
        }
    }

    private func applyChartValue(
        _ value: String,
        to settings: RuuviLocalSettings
    ) -> Bool {
        switch self {
        case .chartShowAllPoints:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.chartDownsamplingOn, !value) {
                settings.chartDownsamplingOn = $0
            }
        case .chartDrawDots:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            guard value != settings.chartDrawDotsOn else { return false }
            // Preserve existing behavior: this feature is disabled for performance,
            // so cloud sync must not re-enable it.
            settings.chartDrawDotsOn = false
            return true
        case .chartShowMinMaxAverage:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.chartStatsOn, value) {
                settings.chartStatsOn = $0
            }
        default:
            preconditionFailure("Unexpected chart setting")
        }
    }

    private func applyDashboardValue(
        _ value: String,
        to settings: RuuviLocalSettings
    ) -> Bool {
        switch self {
        case .cloudModeEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.cloudModeEnabled, value) {
                settings.cloudModeEnabled = $0
            }
        case .dashboardEnabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.dashboardEnabled, value) {
                settings.dashboardEnabled = $0
            }
        case .dashboardType:
            guard let value = value.ruuviCloudApiSettingsDashboardTypeOptional else { return false }
            return update(settings.dashboardType, value) {
                settings.dashboardType = $0
            }
        case .dashboardTapActionType:
            guard let value = value.ruuviCloudApiSettingsDashboardTapActionTypeOptional else { return false }
            return update(settings.dashboardTapActionType, value) {
                settings.dashboardTapActionType = $0
            }
        default:
            preconditionFailure("Unexpected dashboard setting")
        }
    }

    private func applyAccountValue(
        _ value: String,
        to settings: RuuviLocalSettings
    ) -> Bool {
        switch self {
        case .emailAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.emailAlertDisabled, value) {
                settings.emailAlertDisabled = $0
            }
        case .pushAlertDisabled:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.pushAlertDisabled, value) {
                settings.pushAlertDisabled = $0
            }
        case .marketingPreference:
            guard let value = value.ruuviCloudApiSettingBoolean else { return false }
            return update(settings.marketingPreference, value) {
                settings.marketingPreference = $0
            }
        case .profileLanguageCode:
            return update(settings.cloudProfileLanguageCode, Optional(value)) {
                settings.cloudProfileLanguageCode = $0
            }
        case .dashboardSensorOrder:
            guard let value = RuuviCloudApiHelper.jsonArrayFromString(value) else { return false }
            return update(settings.dashboardSensorOrder, value) {
                settings.dashboardSensorOrder = $0
            }
        default:
            preconditionFailure("Unexpected account setting")
        }
    }

    private func update<T: Equatable>(
        _ oldValue: T,
        _ newValue: T,
        apply: (T) -> Void
    ) -> Bool {
        guard oldValue != newValue else {
            return false
        }
        apply(newValue)
        return true
    }
}
