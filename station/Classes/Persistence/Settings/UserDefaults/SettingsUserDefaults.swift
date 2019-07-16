import Foundation

class SettingsUserDegaults: Settings {
    
    var humidityUnit: HumidityUnit {
        get {
            return useAbsoluteHumidity ? .gm3 : .percent
        }
        set {
            useAbsoluteHumidity = newValue == .gm3
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
    
    private var useAbsoluteHumidity: Bool {
        get {
            return UserDefaults.standard.bool(forKey: useAbsoluteHumidityUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useAbsoluteHumidityUDKey)
        }
    }
    private let useAbsoluteHumidityUDKey = "SettingsUserDegaults.useAbsoluteHumidity"
}
