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
    case pushAlertEnabled = "ALERT_PUSH_ENABLED"
    case emailAlertEnabled = "ALERT_EMAIL_ENABLED"
    case profileLanguageCode = "PROFILE_LANGUAGE_CODE"
}

extension TemperatureUnit {
    public var ruuviCloudApiSettingString: String {
        switch self {
        case .celsius:
            return "C"
        case .fahrenheit:
            return "F"
        case .kelvin:
            return "K"
        }
    }
}

extension HumidityUnit {
    public var ruuviCloudApiSettingString: String {
        switch self {
        case .percent:
            return "0"
        case .gm3:
            return "1"
        case .dew:
            return "2"
        }
    }
}

extension UnitPressure {
    public var ruuviCloudApiSettingString: String {
        switch self {
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

extension Int {
    public var ruuviCloudApiSettingString: String {
        return String(self)
    }
}

extension Bool {
    public var chartBoolSettingString: String {
        return self ? "true" : "false"
    }
}

extension String {
    public var ruuviCloudApiSettingUnitTemperature: TemperatureUnit? {
        switch self {
        case "C":
            return .celsius
        case "F":
            return .fahrenheit
        case "K":
            return .kelvin
        default:
            return nil
        }
    }

    public var ruuviCloudApiSettingUnitHumidity: HumidityUnit? {
        switch self {
        case "0":
            return .percent
        case "1":
            return .gm3
        case "2":
            return .dew
        default:
            return nil
        }
    }

    public var ruuviCloudApiSettingUnitPressure: UnitPressure? {
        switch self {
        case "0":
            // v2.0 -> iOS doesn't support Pa. Instead when Pa
            // is received from sync we set hPa on iOS.
            return .hectopascals
        case "1":
            return .hectopascals
        case "2":
            return .millimetersOfMercury
        case "3":
            return .inchesOfMercury
        default:
            return nil
        }
    }

    public var ruuviCloudApiSettingBoolean: Bool? {
        switch self {
        case "true":
            return true
        case "false":
            return false
        default:
            return nil
        }
    }

    public var ruuviCloudApiSettingChartViewPeriod: Int? {
        return Int(self)
    }

    public var ruuviCloudApiSettingsMeasurementAccuracyUnit: MeasurementAccuracyType {
        switch self {
        case "0":
            return .zero
        case "1":
            return .one
        case "2":
            return .two
        default:
            return .two
        }
    }

    public var ruuviCloudApiSettingsDashboardType: DashboardType {
        switch self {
        case "image":
            return .image
        case "simple":
            return .simple
        default:
            return .image
        }
    }

    public var ruuviCloudApiSettingsDashboardTapActionType: DashboardTapActionType {
        switch self {
        case "card":
            return .card
        case "chart":
            return .chart
        default:
            return .card
        }
    }
}
