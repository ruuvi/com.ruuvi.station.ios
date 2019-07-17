import Foundation

class SettingsUserDegaults: Settings {
    
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
            return useFahrenheit ? .fahrenheit : .celsius
        }
        set {
            useFahrenheit = newValue == .fahrenheit
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
    
    var experimentalUX: Bool {
        get {
            return UserDefaults.standard.bool(forKey: experimentalUXUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: experimentalUXUDKey)
        }
    }
    private let experimentalUXUDKey = "SettingsUserDegaults.experimentalUX"
    
    private var useFahrenheit: Bool {
        get {
            return UserDefaults.standard.bool(forKey: useFahrenheitUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useFahrenheitUDKey)
        }
    }
    private let useFahrenheitUDKey = "SettingsUserDegaults.useFahrenheit"
    
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
