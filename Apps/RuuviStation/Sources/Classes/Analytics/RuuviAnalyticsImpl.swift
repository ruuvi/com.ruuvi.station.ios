import Foundation
import FirebaseAnalytics
import RuuviAnalytics
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage
import RuuviUser

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
        // Quantity of tags using data format 2
        case df2_tags(Int)
        // Quantity of tags using data format 3
        case df3_tags(Int)
        // Quantity of tags using data format 4
        case df4_tags(Int)
        // Quantity of tags using data format 5
        case df5_tags(Int)
        // Quantity of tags using data format C5
        case dfC5_tags(Int)
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
                "logged_in"
            case .addedTags:
                "added_tags"
            case .claimedTags:
                "claimed_tags"
            case .offlineTags:
                "offline_tags"
            case .df2_tags:
                "use_df2"
            case .df3_tags:
                "use_df3"
            case .df4_tags:
                "use_df4"
            case .df5_tags:
                "use_df5"
            case .dfC5_tags:
                "use_dfC5"
            case .backgroundScanEnabled:
                "background_scan_enabled"
            case .backgroundScanInterval:
                "background_scan_interval"
            case .dashboardEnabled:
                "dashboard_enabled"
            case .gatewayEnabled:
                "gateway_enabled"
            case .graphDrawDots:
                "graph_draw_dots"
            case .graphPointInterval:
                "graph_point_interval"
            case .graphShowAllPoints:
                "graph_show_all_points"
            case .graphViewPeriod:
                "graph_view_period"
            case .humidityUnit:
                "humidity_unit"
            case .pressureUnit:
                "pressure_unit"
            case .temperatureUnit:
                "temperature_unit"
            case .language:
                "language"
            case .useSimpleWidget:
                "use_simple_widget"
            case .alertTemperature:
                "alert_temperature"
            case .alertHumidity:
                "alert_humidity"
            case .alertPressure:
                "alert_pressure"
            case .alertMovement:
                "alert_movement"
            case .alertRSSI:
                "alert_rssi"
            }
        }
    }

    private let ruuviUser: RuuviUser
    private let ruuviStorage: RuuviStorage
    private let settings: RuuviLocalSettings
    private let alertService: RuuviServiceAlert

    public init(
        ruuviUser: RuuviUser,
        ruuviStorage: RuuviStorage,
        settings: RuuviLocalSettings,
        alertService: RuuviServiceAlert
    ) {
        self.ruuviUser = ruuviUser
        self.ruuviStorage = ruuviStorage
        self.settings = settings
        self.alertService = alertService
    }

    public func update() {
        guard let bundleName = Bundle.main.infoDictionary?["CFBundleName"] as? String,
              bundleName != "station_dev"
        else {
            return
        }
        set(.loggedIn(ruuviUser.isAuthorized))
        ruuviStorage.readAll().on(success: { tags in
            // Version 2/3/4 tags isOwner property was set 'false' in iOS app until version v1.1.0
            // So we log them first before filtering
            let df2_tags_count = tags.filter { $0.version == 2 }.count
            let df3_tags_count = tags.filter { $0.version == 3 }.count
            let df4_tags_count = tags.filter { $0.version == 4 }.count
            let df5_tags_count = tags.filter { $0.version == 5 }.count
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
        set(.backgroundScanEnabled(settings.saveHeartbeats))
        set(.backgroundScanInterval(settings.saveHeartbeatsIntervalMinutes * 60))
        set(.dashboardEnabled(false))
        set(.gatewayEnabled(false))
        set(.graphDrawDots(settings.chartDrawDotsOn))
        set(.graphPointInterval(settings.chartIntervalSeconds / 60))
        set(.graphShowAllPoints(!settings.chartDownsamplingOn))
        set(.graphViewPeriod(settings.dataPruningOffsetHours / 24))
        set(.humidityUnit(settings.humidityUnit))
        set(.pressureUnit(settings.pressureUnit))
        set(.temperatureUnit(settings.temperatureUnit))
        set(.language(settings.language))
        set(.useSimpleWidget(settings.useSimpleWidget))
        set(.alertRSSI(0))
    }

    public func setConsent(allowed: Bool) {
        setConsentSettings(allowed: allowed)
    }

    private func set(_ property: Properties) {
        let value: String = switch property {
        case let .loggedIn(isLoggedIn):
            isLoggedIn.description
        case let .addedTags(count),
             let .claimedTags(count),
             let .offlineTags(count),
             let .df2_tags(count),
             let .df3_tags(count),
             let .df4_tags(count),
             let .df5_tags(count),
             let .dfC5_tags(count),
             let .alertTemperature(count),
             let .alertHumidity(count),
             let .alertPressure(count),
             let .alertMovement(count),
             let .alertRSSI(count):
            count > 10 ? "10+" : String(count)
        case let .backgroundScanEnabled(isEnabled),
             let .dashboardEnabled(isEnabled),
             let .gatewayEnabled(isEnabled),
             let .graphDrawDots(isEnabled),
             let .graphShowAllPoints(isEnabled):
            isEnabled.description
        case let .backgroundScanInterval(intValue),
             let .graphPointInterval(intValue),
             let .graphViewPeriod(intValue):
            String(intValue)
        case let .humidityUnit(unit):
            unit.analyticsValue
        case let .pressureUnit(unit):
            unit.analyticsValue
        case let .temperatureUnit(unit):
            unit.analyticsValue
        case let .language(language):
            language.rawValue
        case let .useSimpleWidget(isUsing):
            isUsing.description
        }
        #if DEBUG || ALPHA
        // skip using analytics
        #else
        Analytics.setUserProperty(value, forName: property.name)
        #endif
    }

    // swiftlint:disable:next large_tuple
    private func calculateAlerts(from tags: [RuuviTagSensor]) -> (
        temperature: Int,
        humidity: Int,
        pressure: Int,
        movementCounter: Int
    ) {
        var temperatureAlertCount = 0
        var humidityAlertCount = 0
        var pressureAlertCount = 0
        var movementAlertCount = 0

        for tag in tags {
            if alertService.isOn(
                type: .temperature(lower: 0, upper: 0),
                for: tag
            ) {
                temperatureAlertCount += 1
            }

            if alertService.isOn(
                type: .relativeHumidity(lower: 0, upper: 0),
                for: tag
            ) {
                humidityAlertCount += 1
            }

            if alertService.isOn(
                type: .pressure(lower: 0, upper: 0),
                for: tag
            ) {
                pressureAlertCount += 1
            }

            if alertService.isOn(
                type: .movement(last: 0),
                for: tag
            ) {
                movementAlertCount += 1
            }
        }
        return (temperatureAlertCount, humidityAlertCount, pressureAlertCount, movementAlertCount)
    }

    private func setConsentSettings(allowed: Bool) {
        let consentSettings: [ConsentType: ConsentStatus] = [
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied,
            .analyticsStorage: allowed ? .granted : .denied,
        ]
        #if DEBUG || ALPHA
        // skip using analytics
        #else
        Analytics.setConsent(consentSettings)
        #endif
    }
}

private extension HumidityUnit {
    // Humidity unit (0-relative, 1-absolute, 2-dew point)
    var analyticsValue: String {
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

private extension UnitPressure {
    // Pressure unit (0-pascal, 1-hectopascal, 2-mmHg, 3-inHg)
    var analyticsValue: String {
        switch self {
        case .hectopascals:
            "1"
        case .millimetersOfMercury:
            "2"
        case .inchesOfMercury:
            "3"
        default:
            "-1"
        }
    }
}

private extension TemperatureUnit {
    // Temperature unit (C-Celsius, F-Fahrenheit, K-Kelvin)
    var analyticsValue: String {
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
