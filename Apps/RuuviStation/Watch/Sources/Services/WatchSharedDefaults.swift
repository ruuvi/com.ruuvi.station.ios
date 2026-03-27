import Foundation

enum WatchSharedDefaults {
    static let suiteName = "group.com.ruuvi.station.widgets"
    static let watchApiKeyKey = "watch.apiKey"
    static let languageKey = "languageKey"
    static let temperatureUnitKey = "temperatureUnitKey"
    static let temperatureAccuracyKey = "temperatureAccuracyKey"
    static let humidityUnitKey = "humidityUnitKey"
    static let humidityAccuracyKey = "humidityAccuracyKey"
    static let pressureUnitKey = "pressureUnitKey"
    static let pressureAccuracyKey = "pressureAccuracyKey"
    static let useDevServerKey = "useDevServerKey"

    static let syncedSettingKeys = [
        languageKey,
        temperatureUnitKey,
        temperatureAccuracyKey,
        humidityUnitKey,
        humidityAccuracyKey,
        pressureUnitKey,
        pressureAccuracyKey,
        useDevServerKey,
    ]
}
