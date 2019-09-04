import Foundation

class SettingsUserDegaults: Settings {
    
    var language: Language {
        get {
            if let savedCode = UserDefaults.standard.string(forKey: languageUDKey) {
                return Language(rawValue: savedCode) ?? .english
            } else if let regionCode = Locale.current.regionCode {
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
    
    var welcomeShown: Bool {
        get {
            return UserDefaults.standard.bool(forKey: welcomeShownUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: welcomeShownUDKey)
        }
    }
    private let welcomeShownUDKey = "SettingsUserDegaults.welcomeShown"
    
    private var useFahrenheit: Bool {
        get {
            return UserDefaults.standard.bool(forKey: useFahrenheitUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useFahrenheitUDKey)
        }
    }
    private let useFahrenheitUDKey = "SettingsUserDegaults.useFahrenheit"
    
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
}
