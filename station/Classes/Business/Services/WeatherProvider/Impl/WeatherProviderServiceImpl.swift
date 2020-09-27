import Foundation
import Future
import CoreLocation

class WeatherProviderServiceImpl: WeatherProviderService {

    var owmApi: OpenWeatherMapAPI!
    var locationManager: LocationManager!
    var locationService: LocationService!

    @discardableResult
    func observeData<T: AnyObject>(_ observer: T,
                                   coordinate: CLLocationCoordinate2D,
                                   provider: WeatherProvider,
                                   interval: TimeInterval,
                                   fire: Bool = true,
                                   closure: @escaping (T, WPSData?, RUError?) -> Void) -> RUObservationToken {
        let timer = Timer.scheduledTimer(withTimeInterval: interval,
                                         repeats: true) { [weak self, weak observer] timer in
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

        if fire {
            timer.fire()
        }

        return RUObservationToken {
            timer.invalidate()
        }
    }

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T,
                                                  provider: WeatherProvider,
                                                  interval: TimeInterval,
                                                  fire: Bool = true,
                                                  closure: @escaping (T, WPSData?, Location?, RUError?) -> Void)
        -> RUObservationToken {

        let timer = Timer.scheduledTimer(withTimeInterval: interval,
                                         repeats: true) { [weak self, weak observer] timer in
            guard let observer = observer else {
                timer.invalidate()
                return
            }
            if let operation = self?.loadCurrentLocationData(from: provider) {
                operation.on(success: { result in
                    if timer.isValid {
                        closure(observer, result.1, result.0, nil)
                    }
                }, failure: { (error) in
                    if timer.isValid {
                        closure(observer, nil, nil, error)
                    }
                })
            } else {
                timer.invalidate()
            }
        }

        if fire {
            timer.fire()
        }

        return RUObservationToken {
            timer.invalidate()
        }
    }

    func loadCurrentLocationData(from provider: WeatherProvider) -> Future<(Location, WPSData), RUError> {
        let promise = Promise<(Location, WPSData), RUError>()
        let coordinate = locationManager.getCurrentLocation()

        coordinate.on(success: { [weak self] (coordinate) in
            self?.loadCurrentLocationData(for: coordinate, provider: provider, with: promise)
        }, failure: { (error) in
            promise.fail(error: error)
        })
        return promise.future
    }

    private func loadCurrentLocationData(for coordinate: CLLocation,
                                         provider: WeatherProvider,
                                         with promise: Promise<(Location, WPSData), RUError>) {
        let location = locationService.reverseGeocode(coordinate: coordinate.coordinate)
        location.on(success: { [weak self] (locations) in
            guard let location = locations.last else {
                promise.fail(error: .unexpected(.failedToReverseGeocodeCoordinate))
                return
            }

            guard let op = self?.loadData(coordinate: location.coordinate, provider: provider) else {
                promise.fail(error: .unexpected(.callerDeinitedDuringOperation))
                return
            }

            op.on(success: { (data) in
                promise.succeed(value: (location, data))
            }, failure: { (error) in
                promise.fail(error: error)
            })

        }, failure: { (error) in
            promise.fail(error: error)
        })
    }

    func loadData(coordinate: CLLocationCoordinate2D, provider: WeatherProvider) -> Future<WPSData, RUError> {
        let promise = Promise<WPSData, RUError>()
        switch provider {
        case .openWeatherMap:
            let api = self.owmApi.loadCurrent(longitude: coordinate.longitude, latitude: coordinate.latitude)
            api.on(success: { (data) in
                var celsius: Double?
                if let kelvin = data.kelvin {
                    celsius = kelvin - 273.15
                }
                let result = WPSData(celsius: celsius, relativeHumidity: data.humidity, hPa: data.pressure)
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: error)
            })
        }
        return promise.future
    }

}
