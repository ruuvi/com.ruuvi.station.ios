import Foundation

class SettingsUserDegaults: Settings {

    private let keepConnectionDialogWasShownUDPrefix = "SettingsUserDegaults.keepConnectionDialogWasShownUDPrefix."

    func keepConnectionDialogWasShown(for luid: LocalIdentifier) -> Bool {
        return UserDefaults.standard.bool(forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    func setKeepConnectionDialogWasShown(for luid: LocalIdentifier) {
        UserDefaults.standard.set(true, forKey: keepConnectionDialogWasShownUDPrefix + luid.value)
    }

    var language: Language {
        get {
            if let savedCode = UserDefaults.standard.string(forKey: languageUDKey) {
                return Language(rawValue: savedCode) ?? .english
            } else if let regionCode = Locale.current.languageCode {
                return Language(rawValue: regionCode) ?? .english
            } else {
                return .english
            }
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageUDKey)
            NotificationCenter
                .default
                .post(name: .LanguageDidChange,
                      object: self,
                      userInfo: nil)
        }
    }
    private let languageUDKey = "SettingsUserDegaults.languageUDKey"

    var humidityUnit: HumidityUnit {
        get {
            switch humidityUnitInt {
            case 1:
                return .gm3
            case 2:
                return .dew
            default:
                return .percent
            }
        }
        set {
            switch newValue {
            case .percent:
                humidityUnitInt = 0
            case .gm3:
                humidityUnitInt = 1
            case .dew:
                humidityUnitInt = 2
            }
            NotificationCenter
                .default
                .post(name: .HumidityUnitDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    var temperatureUnit: TemperatureUnit {
        get {
            switch temperatureUnitInt {
            case 0:
                return useFahrenheit ? .fahrenheit : .celsius
            case 1:
                return .kelvin
            case 2:
                return .celsius
            case 3:
                return .fahrenheit
            default:
                return .celsius
            }
        }
        set {
            useFahrenheit = newValue == .fahrenheit
            switch newValue {
            case .kelvin:
                temperatureUnitInt = 1
            case .celsius:
                temperatureUnitInt = 2
            case .fahrenheit:
                temperatureUnitInt = 3
            }
            NotificationCenter
                .default
                .post(name: .TemperatureUnitDidChange,
                      object: self,
                      userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.welcomeShown", defaultValue: false)
    var welcomeShown: Bool

    @UserDefault("SettingsUserDegaults.tagChartsLandscapeSwipeInstructionWasShown", defaultValue: false)
    var tagChartsLandscapeSwipeInstructionWasShown: Bool

    @UserDefault("DashboardScrollViewController.hasShownSwipeAlert", defaultValue: false)
     var cardsSwipeHintWasShown: Bool

    @UserDefault("SettingsUserDegaults.isAdvertisementDaemonOn", defaultValue: true)
    var isAdvertisementDaemonOn: Bool {
        didSet {
            NotificationCenter
            .default
            .post(name: .isAdvertisementDaemonOnDidChange,
                  object: self,
                  userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.isWebTagDaemonOn", defaultValue: true)
    var isWebTagDaemonOn: Bool {
        didSet {
            NotificationCenter
            .default
            .post(name: .isWebTagDaemonOnDidChange,
                  object: self,
                  userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.webTagDaemonIntervalMinutes", defaultValue: 60)
    var webTagDaemonIntervalMinutes: Int {

        didSet {
            NotificationCenter
            .default
            .post(name: .WebTagDaemonIntervalDidChange,
             object: self,
             userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.connectionTimeout", defaultValue: 15)
    var connectionTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.serviceTimeout", defaultValue: 60)
    var serviceTimeout: TimeInterval

    @UserDefault("SettingsUserDegaults.advertisementDaemonIntervalMinutes", defaultValue: 5)
    var advertisementDaemonIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.alertsRepeatingIntervalMinutes", defaultValue: 60)
    var alertsRepeatingIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.saveHeartbeats", defaultValue: false)
    var saveHeartbeats: Bool

    @UserDefault("SettingsUserDegaults.saveHeartbeatsIntervalMinutes", defaultValue: 5)
    var saveHeartbeatsIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.webPullIntervalMinutes", defaultValue: 15)
    var webPullIntervalMinutes: Int

    @UserDefault("SettingsUserDegaults.readRSSI", defaultValue: true)
    var readRSSI: Bool {
        didSet {
            NotificationCenter
            .default
            .post(name: .ReadRSSIDidChange,
             object: self,
             userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.readRSSIIntervalSeconds", defaultValue: 5)
    var readRSSIIntervalSeconds: Int {
        didSet {
            NotificationCenter
            .default
            .post(name: .ReadRSSIIntervalDidChange,
             object: self,
             userInfo: nil)
        }
    }

    @UserDefault("SettingsUserDegaults.dataPruningOffsetHours", defaultValue: 72)
    var dataPruningOffsetHours: Int

    @UserDefault("SettingsUserDegaults.chartIntervalSeconds", defaultValue: 300)
    var chartIntervalSeconds: Int

    @UserDefault("SettingsUserDegaults.chartDurationHours", defaultValue: 72)
    var chartDurationHours: Int

    @UserDefault("SettingsUserDefaults.TagsSorting", defaultValue: [])
    var tagsSorting: [String]

    @UserDefault("SettingsUserDegaults.useFahrenheit", defaultValue: false)
    private var useFahrenheit: Bool

    private var temperatureUnitInt: Int {
        get {
            let int = UserDefaults.standard.integer(forKey: temperatureUnitIntUDKey)
            if int == 0 {
                if useFahrenheit {
                    temperatureUnit = .fahrenheit
                    return 3
                } else {
                    temperatureUnit = .celsius
                    return 2
                }
            } else {
                return int
            }
        }
        set {
            UserDefaults.standard.set(newValue, forKey: temperatureUnitIntUDKey)
        }
    }
    private let temperatureUnitIntUDKey = "SettingsUserDegaults.temperatureUnitIntUDKey"

    private var humidityUnitInt: Int {
        get {
            return UserDefaults.standard.integer(forKey: humidityUnitIntUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: humidityUnitIntUDKey)
        }
    }
    private let humidityUnitIntUDKey = "SettingsUserDegaults.humidityUnitInt"

    @UserDefault("SettingsUserDefaults.chartDownsamplingOn", defaultValue: false)
    var chartDownsamplingOn: Bool {
        didSet {
            NotificationCenter
                .default
                .post(name: .DownsampleOnDidChange,
                      object: self,
                      userInfo: nil)
        }
    }
}
