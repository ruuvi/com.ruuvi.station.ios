import Foundation
import Future

protocol WebTagService {
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError>
    func loadData(from provider: WeatherProvider) -> Future<WebTagData,RUError>
}

struct WebTagData {
    var celsius: Double?
    var humidity: Double?
    var pressure: Double?
    
    var fahrenheit: Double? {
        if let celsius = celsius {
            return (celsius * 9.0/5.0) + 32.0
        } else {
            return nil
        }
    }
}
