import Foundation
import Future
import CoreLocation

struct WPSData {
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
    
    var kelvin: Double? {
        if let celsius = celsius {
            return celsius + 273.15
        } else {
            return nil
        }
    }
}

protocol WeatherProviderService {
    
    func loadData(coordinate: CLLocationCoordinate2D, provider: WeatherProvider) -> Future<WPSData,RUError>
    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<(Location,WPSData),RUError>
    
    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T, provider: WeatherProvider, interval: TimeInterval, fire: Bool, closure: @escaping (T, WPSData?, Location?, RUError?) -> Void) -> RUObservationToken
    
    @discardableResult
    func observeData<T: AnyObject>(_ observer: T, coordinate: CLLocationCoordinate2D, provider: WeatherProvider, interval: TimeInterval, fire: Bool, closure: @escaping (T, WPSData?, RUError?) -> Void) -> RUObservationToken
}

