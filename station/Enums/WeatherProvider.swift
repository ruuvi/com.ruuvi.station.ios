import Foundation

enum WeatherProvider {
    case openWeatherMap
    
    var name: String {
        switch self {
        case .openWeatherMap:
            return "openWeatherMap"
        }
    }
    
    var displayName: String {
        switch self {
        case .openWeatherMap:
            return "WeatherProvider.OpenWeatherMap.displayName".localized()
        }
    }
}
