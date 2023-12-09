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
            // v2.0 -> iOS doesn't support Pa. Instead when Pa
            // is received from sync we set hPa on iOS.
            .hectopascals
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
        case "true":
            true
        case "false":
            false
        default:
            nil
        }
    }

    var ruuviCloudApiSettingChartViewPeriod: Int? {
        Int(self)
    }

    var ruuviCloudApiSettingsMeasurementAccuracyUnit: MeasurementAccuracyType {
        switch self {
        case "0":
            .zero
        case "1":
            .one
        case "2":
            .two
        default:
            .two
        }
    }

    var ruuviCloudApiSettingsDashboardType: DashboardType {
        switch self {
        case "image":
            .image
        case "simple":
            .simple
        default:
            .image
        }
    }

    var ruuviCloudApiSettingsDashboardTapActionType: DashboardTapActionType {
        switch self {
        case "card":
            .card
        case "chart":
            .chart
        default:
            .card
        }
    }
}
