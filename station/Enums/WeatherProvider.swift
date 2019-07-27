import Foundation

enum WeatherProvider: String, CaseIterable {
    case openWeatherMap = "openWeatherMap"
    
    var displayName: String {
        switch self {
        case .openWeatherMap:
            return "WeatherProvider.OpenWeatherMap.displayName".localized()
        }
    }
}
