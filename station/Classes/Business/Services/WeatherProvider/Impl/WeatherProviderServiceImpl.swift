import Foundation
import Future
import CoreLocation

class WeatherProviderServiceImpl: WeatherProviderService {
    
    var owmApi: OpenWeatherMapAPI!
    var locationManager: LocationManager!
    
    @discardableResult
    func observeData<T: AnyObject>(_ observer: T, coordinate: CLLocationCoordinate2D, provider: WeatherProvider, interval: TimeInterval, closure: @escaping (T, WPSData?, RUError?) -> Void) -> WPSObservationToken {
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak observer] timer in
            guard let observer = observer else {
                timer.invalidate()
                return
            }
            if let operation = self?.loadData(coordinate: coordinate, provider: provider) {
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
        
        return WPSObservationToken {
            timer.invalidate()
        }
    }
    
    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T, provider: WeatherProvider, interval: TimeInterval, closure: @escaping (T, WPSData?, RUError?) -> Void) -> WPSObservationToken {
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self, weak observer] timer in
            guard let observer = observer else {
                timer.invalidate()
                return
            }
            if let operation = self?.loadCurrentLocationData(from: provider) {
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
        
        return WPSObservationToken {
            timer.invalidate()
        }
    }
    
    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<WPSData,RUError> {
        let promise = Promise<WPSData,RUError>()
        locationManager.getCurrentLocation { [weak self] (location) in
            if let location = location {
                guard let op = self?.loadData(coordinate: location.coordinate, provider: provider) else {
                    promise.fail(error: .unexpected(.callerDeinitedDuringOperation))
                    return
                }
                op.on(success: { (data) in
                    promise.succeed(value: data)
                }, failure: { (error) in
                    promise.fail(error: error)
                })
            } else {
                promise.fail(error: .core(.failedToGetCurrentLocation))
            }
        }
        return promise.future
    }
    
    func loadData(coordinate: CLLocationCoordinate2D, provider: WeatherProvider) -> Future<WPSData,RUError> {
        let promise = Promise<WPSData,RUError>()
        switch provider {
        case .openWeatherMap:
            let api = self.owmApi.loadCurrent(longitude: coordinate.longitude, latitude: coordinate.latitude)
            api.on(success: { (data) in
                var celsius: Double? = nil
                if let kelvin = data.kelvin {
                    celsius = kelvin - 273.15
                }
                let result = WPSData(celsius: celsius, humidity: data.humidity, pressure: data.pressure)
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: error)
            })
        }
        return promise.future
    }
    
}
