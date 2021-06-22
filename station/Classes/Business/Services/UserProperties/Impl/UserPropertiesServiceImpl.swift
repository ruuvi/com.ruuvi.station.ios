import Foundation
import Future
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
import RuuviStorage
import RuuviOntology
import RuuviLocal

final class UserPropertiesServiceImpl: UserPropertiesService {
    private enum Properties {
        // Quantity of added tags(if greater that 10, then "10+")
        case addedTags(Int)
        // Background scan enabled or not (true/false)
        case backgroundScanEnabled(Bool)
        // Background scan interval (seconds)
        case backgroundScanInterval(Int)
        // Dashboard view enabled (true/false)
        case dashboardEnabled(Bool)
        // Gateway URL is filled with some data (true/false)
        case gatewayEnabled(Bool)
        // Draw dots on graph enabled (true/false)
        case graphDrawDots(Bool)
        // Interval between points in graph (minutes)
        case graphPointInterval(Int)
        // Show all points from DB in graph (true/false)
        case graphShowAllPoints(Bool)
        // Graph view period (hours)
        case graphViewPeriod(Int)
        // Humidity unit (0-relative, 1-absolute, 2-dew point)
        case humidityUnit(HumidityUnit)
        // Pressure unit (0-pascal, 1-hectopascal, 2-mmHg, 3-inHg)
        case pressureUnit(UnitPressure)
        // Temperature unit (C-Celsius, F-Fahrenheit, K-Kelvin)
        case temperatureUnit(TemperatureUnit)
        // Selected application language (ru/fi/en/sv)
        case language(Language)

        var name: String {
            switch self {
            case .addedTags:
                return "added_tags"
            case .backgroundScanEnabled:
                return "background_scan_enabled"
            case .backgroundScanInterval:
                return "background_scan_interval"
            case .dashboardEnabled:
                return "dashboard_enabled"
            case .gatewayEnabled:
                return "gateway_enabled"
            case .graphDrawDots:
                return "graph_draw_dots"
            case .graphPointInterval:
                return "graph_point_interval"
            case .graphShowAllPoints:
                return "graph_show_all_points"
            case .graphViewPeriod:
                return "graph_view_period"
            case .humidityUnit:
                return "humidity_unit"
            case .pressureUnit:
                return "pressure_unit"
            case .temperatureUnit:
                return "temperature_unit"
            case .language:
                return "language"
            }
        }
    }

    var ruuviStorage: RuuviStorage!
    var settings: RuuviLocalSettings!

    func update() {
        guard let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String,
              bundleName != "station_dev" else {
            return
        }
        ruuviStorage.readAll().on(success: { tags in
            self.set(.addedTags(tags.count))
        })
        set(.backgroundScanEnabled(settings.saveHeartbeats))
        set(.backgroundScanInterval(settings.saveHeartbeatsIntervalMinutes * 60))
        set(.dashboardEnabled(false))
        set(.gatewayEnabled(false))
        set(.graphDrawDots(settings.chartDownsamplingOn))
        set(.graphPointInterval(settings.chartIntervalSeconds / 60))
        set(.graphShowAllPoints(false))
        set(.graphViewPeriod(settings.dataPruningOffsetHours))
        set(.humidityUnit(settings.humidityUnit))
        set(.pressureUnit(settings.pressureUnit))
        set(.temperatureUnit(settings.temperatureUnit))
        set(.language(settings.language))
    }

    private func set(_ property: Properties) {
        let value: String
        switch property {
        case .addedTags(let count):
            value = count > 10 ? "10+" : String(count)
        case .backgroundScanEnabled(let isEnabled),
             .dashboardEnabled(let isEnabled),
             .gatewayEnabled(let isEnabled),
             .graphDrawDots(let isEnabled),
             .graphShowAllPoints(let isEnabled):
            value = isEnabled.description
        case .backgroundScanInterval(let intValue),
             .graphPointInterval(let intValue),
             .graphViewPeriod(let intValue):
            value = String(intValue)
        case .humidityUnit(let unit):
            value = unit.analyticsValue
        case .pressureUnit(let unit):
            value = unit.analyticsValue
        case .temperatureUnit(let unit):
            value = unit.analyticsValue
        case .language(let language):
            value = language.rawValue
        }
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: property.name)
        #endif
    }
}
fileprivate extension HumidityUnit {
    // Humidity unit (0-relative, 1-absolute, 2-dew point)
    var analyticsValue: String {
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
fileprivate extension UnitPressure {
    // Pressure unit (0-pascal, 1-hectopascal, 2-mmHg, 3-inHg)
    var analyticsValue: String {
        switch self {
        case .hectopascals:
            return "1"
        case .millimetersOfMercury:
            return "2"
        case .inchesOfMercury:
            return "3"
        default:
            return "-1"
        }
    }
}
fileprivate extension TemperatureUnit {
    // Temperature unit (C-Celsius, F-Fahrenheit, K-Kelvin)
    var analyticsValue: String {
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
