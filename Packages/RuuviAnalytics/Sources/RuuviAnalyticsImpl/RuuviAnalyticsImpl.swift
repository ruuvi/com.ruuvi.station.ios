import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif
import RuuviAnalytics
import RuuviOntology
import RuuviStorage
import RuuviLocal
import RuuviVirtual
import RuuviUser
import RuuviService

public final class RuuviAnalyticsImpl: RuuviAnalytics {
    private enum Properties {
        // Observe logged in users
        case loggedIn(Bool)
        // Quantity of added tags(if greater that 10, then "10+")
        case addedTags(Int)
        // Quantity of claimed tags by the user(if greater that 10, then "10+")
        case claimedTags(Int)
        // Quantity of offline tags[only local tags](if greater that 10, then "10+")
        case offlineTags(Int)
        // Quantity of virtual tags(if greater that 10, then "10+")
        case virtualTags(Int)
        // Quantity of tags using data format 2
        case df2_tags(Int)
        // Quantity of tags using data format 3
        case df3_tags(Int)
        // Quantity of tags using data format 4
        case df4_tags(Int)
        // Quantity of tags using data format 5
        case df5_tags(Int)
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
        // Users using simple widget
        case useSimpleWidget(Bool)
        // Number of temperature alerts
        case alertTemperature(Int)
        // Number of humidity alerts
        case alertHumidity(Int)
        // Number of pressure alerts
        case alertPressure(Int)
        // Number of movement counter alerts
        case alertMovement(Int)
        // Number of RSSI alert
        case alertRSSI(Int)

        var name: String {
            switch self {
            case .loggedIn:
                return "logged_in"
            case .addedTags:
                return "added_tags"
            case .claimedTags:
                return "claimed_tags"
            case .offlineTags:
                return "offline_tags"
            case .virtualTags:
                return "virtual_tags"
            case .df2_tags:
                return "use_df2"
            case .df3_tags:
                return "use_df3"
            case .df4_tags:
                return "use_df4"
            case .df5_tags:
                return "use_df5"
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
            case .useSimpleWidget:
                return "use_simple_widget"
            case .alertTemperature:
                return "alert_temperature"
            case .alertHumidity:
                return "alert_humidity"
            case .alertPressure:
                return "alert_pressure"
            case .alertMovement:
                return "alert_movement"
            case .alertRSSI:
                return "alert_rssi"
            }
        }
    }

    private let ruuviUser: RuuviUser
    private let ruuviStorage: RuuviStorage
    private let virtualPersistence: VirtualPersistence
    private let settings: RuuviLocalSettings
    private let alertService: RuuviServiceAlert

    public init(
        ruuviUser: RuuviUser,
        ruuviStorage: RuuviStorage,
        virtualPersistence: VirtualPersistence,
        settings: RuuviLocalSettings,
        alertService: RuuviServiceAlert
    ) {
        self.ruuviUser = ruuviUser
        self.ruuviStorage = ruuviStorage
        self.virtualPersistence = virtualPersistence
        self.settings = settings
        self.alertService = alertService
    }

    public func update() {
        guard let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String,
              bundleName != "station_dev" else {
            return
        }
        set(.loggedIn(ruuviUser.isAuthorized))
        ruuviStorage.readAll().on(success: { tags in
            // Version 2/3/4 tags isOwner property was set 'false' in iOS app until version v1.1.0
            // So we log them first before filtering
            let df2_tags_count = tags.filter({ $0.version == 2 }).count
            let df3_tags_count = tags.filter({ $0.version == 3 }).count
            let df4_tags_count = tags.filter({ $0.version == 4 }).count
            let df5_tags_count = tags.filter({ $0.version == 5 }).count
            self.set(.df2_tags(df2_tags_count))
            self.set(.df3_tags(df3_tags_count))
            self.set(.df4_tags(df4_tags_count))
            self.set(.df5_tags(df5_tags_count))
            self.set(.addedTags(tags.count))

            // Alerts
            let (temperature, humidity, pressure, movement) = self.calculateAlerts(from: tags)
            self.set(.alertTemperature(temperature))
            self.set(.alertHumidity(humidity))
            self.set(.alertPressure(pressure))
            self.set(.alertMovement(movement))
        })
        ruuviStorage.getClaimedTagsCount().on(success: { count in
            self.set(.claimedTags(count))
        })
        ruuviStorage.getOfflineTagsCount().on(success: { count in
            self.set(.offlineTags(count))
        })
        virtualPersistence.readAll().on(success: { tags in
            self.set(.virtualTags(tags.count))
        })
        set(.backgroundScanEnabled(settings.saveHeartbeats))
        set(.backgroundScanInterval(settings.saveHeartbeatsIntervalMinutes * 60))
        set(.dashboardEnabled(false))
        set(.gatewayEnabled(false))
        set(.graphDrawDots(settings.chartDrawDotsOn))
        set(.graphPointInterval(settings.chartIntervalSeconds / 60))
        set(.graphShowAllPoints(!settings.chartDownsamplingOn))
        set(.graphViewPeriod(settings.dataPruningOffsetHours/24))
        set(.humidityUnit(settings.humidityUnit))
        set(.pressureUnit(settings.pressureUnit))
        set(.temperatureUnit(settings.temperatureUnit))
        set(.language(settings.language))
        set(.useSimpleWidget(settings.useSimpleWidget))
        set(.alertRSSI(0))
    }

    private func set(_ property: Properties) {
        let value: String
        switch property {
        case .loggedIn(let isLoggedIn):
            value = isLoggedIn.description
        case .addedTags(let count),
            .claimedTags(let count),
            .offlineTags(let count),
            .virtualTags(let count),
            .df2_tags(let count),
            .df3_tags(let count),
            .df4_tags(let count),
            .df5_tags(let count),
            .alertTemperature(let count),
            .alertHumidity(let count),
            .alertPressure(let count),
            .alertMovement(let count),
            .alertRSSI(let count):
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
        case .useSimpleWidget(let isUsing):
            value = isUsing.description
        }
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: property.name)
        #endif
    }

    // swiftlint:disable:next large_tuple
    private func calculateAlerts(from tags: [RuuviTagSensor]) -> (temperature: Int,
                                       humidity: Int,
                                       pressure: Int,
                                       movementCounter: Int) {
        var temperatureAlertCount: Int = 0
        var humidityAlertCount: Int = 0
        var pressureAlertCount: Int = 0
        var movementAlertCount: Int = 0

        for tag in tags {
            if alertService.isOn(type: .temperature(lower: 0, upper: 0),
                                 for: tag) {
                temperatureAlertCount += 1
            }

            if alertService.isOn(type: .relativeHumidity(lower: 0, upper: 0),
                                        for: tag) {
                humidityAlertCount += 1
            }

            if alertService.isOn(type: .pressure(lower: 0, upper: 0),
                                        for: tag) {
                pressureAlertCount += 1
            }

            if alertService.isOn(type: .movement(last: 0),
                                        for: tag) {
                movementAlertCount += 1
            }
        }
        return (temperatureAlertCount, humidityAlertCount, pressureAlertCount, movementAlertCount)
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
