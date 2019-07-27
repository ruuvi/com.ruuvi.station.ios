import Foundation
import Future

class WebTagServiceImpl: WebTagService {
    
    var webTagPersistence: WebTagPersistence!
    var owmApi: OpenWeatherMapAPI!
    var locationManager: LocationManager!
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError> {
        return webTagPersistence.persist(provider: provider)
    }
    
    func loadData(from provider: WeatherProvider) -> Future<WebTagData,RUError> {
        let promise = Promise<WebTagData,RUError>()
        locationManager.getCurrentLocation { (location) in
            if let location = location {
                let lon = location.coordinate.longitude
                let lat = location.coordinate.latitude
                switch provider {
                case .openWeatherMap:
                    let api = self.owmApi.loadCurrent(longitude: lon, latitude: lat)
                    api.on(success: { (data) in
                        var celsius: Double? = nil
                        if let kelvin = data.kelvin {
                            celsius = kelvin - 273.15
                        }
                        let result = WebTagData(celsius: celsius, humidity: data.humidity, pressure: data.pressure)
                        promise.succeed(value: result)
                    }, failure: { (error) in
                        promise.fail(error: error)
                    })
                }
            } else {
                promise.fail(error: .core(.failedToGetCurrentLocation))
            }
        }
        
        return promise.future
    }
}
