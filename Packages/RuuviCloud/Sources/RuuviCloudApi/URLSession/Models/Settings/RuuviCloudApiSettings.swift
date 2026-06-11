import Foundation
import RuuviOntology

public enum RuuviCloudApiSetting: String, CaseIterable, Codable {
    case unitTemperature = "UNIT_TEMPERATURE"
    case accuracyTemperature = "ACCURACY_TEMPERATURE"
    case unitHumidity = "UNIT_HUMIDITY"
    case accuracyHumidity = "ACCURACY_HUMIDITY"
    case unitPressure = "UNIT_PRESSURE"
    case accuracyPressure = "ACCURACY_PRESSURE"
    case chartViewPeriod = "CHART_VIEW_PERIOD"
    case chartShowAllPoints = "CHART_SHOW_ALL_POINTS"
    case chartDrawDots = "CHART_DRAW_DOTS"
    case chartShowMinMaxAverage = "CHART_SHOW_MIN_MAX_AVG"
    case cloudModeEnabled = "CLOUD_MODE_ENABLED"
    case dashboardEnabled = "DASHBOARD_ENABLED"
    case dashboardType = "DASHBOARD_TYPE"
    case dashboardTapActionType = "DASHBOARD_TAP_ACTION"
    case pushAlertDisabled = "DISABLE_PUSH_NOTIFICATIONS"
    case emailAlertDisabled = "DISABLE_EMAIL_NOTIFICATIONS"
    case marketingPreference = "MARKETING_PREFERENCE"
    case profileLanguageCode = "PROFILE_LANGUAGE_CODE"
    case dashboardSensorOrder = "SENSOR_ORDER"
    case sensorDisplayOrder = "displayOrder"
    case sensorDefaultDisplayOrder = "defaultDisplayOrder"
    case sensorDescription = "description"
}

public extension RuuviCloudApiSetting {
    /// Global `/settings` keys. Per-sensor setting keys are intentionally excluded.
    static let userSettingKeys: [RuuviCloudApiSetting] = [
        .unitTemperature,
        .accuracyTemperature,
        .unitHumidity,
        .accuracyHumidity,
        .unitPressure,
        .accuracyPressure,
        .chartViewPeriod,
        .chartShowAllPoints,
        .chartDrawDots,
        .chartShowMinMaxAverage,
        .cloudModeEnabled,
        .dashboardEnabled,
        .dashboardType,
        .dashboardTapActionType,
        .emailAlertDisabled,
        .pushAlertDisabled,
        .marketingPreference,
        .profileLanguageCode,
        .dashboardSensorOrder,
    ]

    /// Settings participating in timestamp-based local/cloud conflict resolution.
    /// `CHART_VIEW_PERIOD` remains API-known, but current app behavior keeps it local-only.
    static let cloudSyncedUserSettings: [RuuviCloudApiSetting] = userSettingKeys.filter {
        $0 != .chartViewPeriod
    }

    var isCloudSyncedUserSetting: Bool {
        Self.cloudSyncedUserSettings.contains(self)
    }
}

public extension RuuviCloudSettings {
    func userSettingValue(for setting: RuuviCloudApiSetting) -> String? {
        userSettings.first { $0.key == setting.rawValue }?.value
    }

    var unitTemperature: TemperatureUnit? {
        userSettingValue(for: .unitTemperature)?.ruuviCloudApiSettingUnitTemperature
    }

    var accuracyTemperature: MeasurementAccuracyType? {
        userSettingValue(for: .accuracyTemperature)?.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional
    }

    var unitHumidity: HumidityUnit? {
        userSettingValue(for: .unitHumidity)?.ruuviCloudApiSettingUnitHumidity
    }

    var accuracyHumidity: MeasurementAccuracyType? {
        userSettingValue(for: .accuracyHumidity)?.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional
    }

    var unitPressure: UnitPressure? {
        userSettingValue(for: .unitPressure)?.ruuviCloudApiSettingUnitPressure
    }

    var accuracyPressure: MeasurementAccuracyType? {
        userSettingValue(for: .accuracyPressure)?.ruuviCloudApiSettingsMeasurementAccuracyUnitOptional
    }

    var chartShowAllPoints: Bool? {
        userSettingValue(for: .chartShowAllPoints)?.ruuviCloudApiSettingBoolean
    }

    var chartDrawDots: Bool? {
        userSettingValue(for: .chartDrawDots)?.ruuviCloudApiSettingBoolean
    }

    var chartViewPeriod: Int? {
        userSettingValue(for: .chartViewPeriod)?.ruuviCloudApiSettingChartViewPeriod
    }

    var chartShowMinMaxAvg: Bool? {
        userSettingValue(for: .chartShowMinMaxAverage)?.ruuviCloudApiSettingBoolean
    }

    var cloudModeEnabled: Bool? {
        userSettingValue(for: .cloudModeEnabled)?.ruuviCloudApiSettingBoolean
    }

    var dashboardEnabled: Bool? {
        userSettingValue(for: .dashboardEnabled)?.ruuviCloudApiSettingBoolean
    }

    var dashboardType: DashboardType? {
        userSettingValue(for: .dashboardType)?.ruuviCloudApiSettingsDashboardTypeOptional
    }

    var dashboardTapActionType: DashboardTapActionType? {
        userSettingValue(for: .dashboardTapActionType)?.ruuviCloudApiSettingsDashboardTapActionTypeOptional
    }

    var pushAlertDisabled: Bool? {
        userSettingValue(for: .pushAlertDisabled)?.ruuviCloudApiSettingBoolean
    }

    var emailAlertDisabled: Bool? {
        userSettingValue(for: .emailAlertDisabled)?.ruuviCloudApiSettingBoolean
    }

    var marketingPreference: Bool? {
        userSettingValue(for: .marketingPreference)?.ruuviCloudApiSettingBoolean
    }

    var profileLanguageCode: String? {
        userSettingValue(for: .profileLanguageCode)
    }

    var dashboardSensorOrder: String? {
        userSettingValue(for: .dashboardSensorOrder)
    }
}

public extension TemperatureUnit {
    var ruuviCloudApiSettingString: String {
        switch self {
        case .celsius:
            "C"
        case .fahrenheit:
            "F"
        case .kelvin:
            "K"
        }
    }
}

public extension HumidityUnit {
    var ruuviCloudApiSettingString: String {
        switch self {
        case .percent:
            "0"
        case .gm3:
            "1"
        case .dew:
            "2"
        }
    }
}

public extension UnitPressure {
    var ruuviCloudApiSettingString: String {
        switch self {
        case .newtonsPerMetersSquared:
            return "0"
        case .hectopascals:
            return "1"
        case .millimetersOfMercury:
            return "2"
        case .inchesOfMercury:
            return "3"
        default:
            assertionFailure()
            return ""
        }
    }
}

public extension Int {
    var ruuviCloudApiSettingString: String {
        String(self)
    }
}

public extension Bool {
    var chartBoolSettingString: String {
        self ? "true" : "false"
    }
}

public extension String {
    var ruuviCloudApiSettingUnitTemperature: TemperatureUnit? {
        switch self {
        case "C":
            .celsius
        case "F":
            .fahrenheit
        case "K":
            .kelvin
        default:
            nil
        }
    }

    var ruuviCloudApiSettingUnitHumidity: HumidityUnit? {
        switch self {
        case "0":
            .percent
        case "1":
            .gm3
        case "2":
            .dew
        default:
            nil
        }
    }

    var ruuviCloudApiSettingUnitPressure: UnitPressure? {
        switch self {
        case "0":
            .newtonsPerMetersSquared
        case "1":
            .hectopascals
        case "2":
            .millimetersOfMercury
        case "3":
            .inchesOfMercury
        default:
            nil
        }
    }

    var ruuviCloudApiSettingBoolean: Bool? {
        switch self {
        case "true", "1":
            true
        case "false", "0":
            false
        default:
            nil
        }
    }

    var ruuviCloudApiSettingChartViewPeriod: Int? {
        Int(self)
    }

    var ruuviCloudApiSettingsMeasurementAccuracyUnitOptional: MeasurementAccuracyType? {
        switch self {
        case "0":
            .zero
        case "1":
            .one
        case "2":
            .two
        default:
            nil
        }
    }

    var ruuviCloudApiSettingsMeasurementAccuracyUnit: MeasurementAccuracyType {
        ruuviCloudApiSettingsMeasurementAccuracyUnitOptional ?? .two
    }

    var ruuviCloudApiSettingsDashboardTypeOptional: DashboardType? {
        switch self {
        case "image":
            .image
        case "simple":
            .simple
        default:
            nil
        }
    }

    var ruuviCloudApiSettingsDashboardType: DashboardType {
        ruuviCloudApiSettingsDashboardTypeOptional ?? .image
    }

    var ruuviCloudApiSettingsDashboardTapActionTypeOptional: DashboardTapActionType? {
        switch self {
        case "card":
            .card
        case "chart":
            .chart
        default:
            nil
        }
    }

    var ruuviCloudApiSettingsDashboardTapActionType: DashboardTapActionType {
        ruuviCloudApiSettingsDashboardTapActionTypeOptional ?? .card
    }
}
