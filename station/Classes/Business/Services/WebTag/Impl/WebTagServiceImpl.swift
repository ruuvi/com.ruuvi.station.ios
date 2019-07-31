import Foundation
import Future

class WebTagServiceImpl: WebTagService {
    
    var webTagPersistence: WebTagPersistence!
    var owmApi: OpenWeatherMapAPI!
    var locationManager: LocationManager!
    
    func add(provider: WeatherProvider) -> Future<WeatherProvider,RUError> {
        return webTagPersistence.persist(provider: provider)
    }
    
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.remove(webTag: webTag)
    }
    
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.update(name: name, of: webTag)
    }
    
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        return webTagPersistence.update(location: location, of: webTag)
    }
    
    @discardableResult
    func observe<T: AnyObject>(_ observer: T, provider: WeatherProvider, interval: TimeInterval, closure: @escaping (T, WebTagData?, RUError?) -> Void) -> WebTagServiceObservationToken {
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak observer] timer in
            guard let observer = observer else {
                timer.invalidate()
                return
            }
            if let operation = self?.loadData(from: provider) {
                operation.on(success: { data in
                    if timer.isValid {
                        closure(observer, data, nil)
                    }
                }, failure: { (error) in
                    if timer.isValid {
                        closure(observer, nil, error)
                    }
                })
            } else {
                timer.invalidate()
            }
        }
        timer.fire()
        
        return WebTagServiceObservationToken {
            timer.invalidate()
        }
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
