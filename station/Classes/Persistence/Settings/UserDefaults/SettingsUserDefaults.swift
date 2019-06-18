import Foundation

class SettingsUserDegaults: Settings {
    
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
    
    private var useFahrenheit: Bool {
        get {
            return UserDefaults.standard.bool(forKey: useFahrenheitUDKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: useFahrenheitUDKey)
        }
    }
    private let useFahrenheitUDKey = "SettingsUserDegaults.useFahrenheit"
}
