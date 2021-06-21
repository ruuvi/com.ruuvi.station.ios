import Foundation
import Future
import CoreLocation
import RuuviVirtual
import RuuviOntology
import RuuviLocation
import RuuviCore

public final class VirtualProviderServiceImpl: VirtualProviderService {
    var owmApi: OpenWeatherMapAPI!
    var locationManager: RuuviCoreLocation!
    var locationService: RuuviLocationService!

    public init(
        owmApi: OpenWeatherMapAPI,
        ruuviCoreLocation: RuuviCoreLocation,
        ruuviLocationService: RuuviLocationService
    ) {
        self.owmApi = owmApi
        self.locationManager = ruuviCoreLocation
        self.locationService = ruuviLocationService
    }

    @discardableResult
    // swiftlint:disable:next function_parameter_count
    public func observeData<T: AnyObject>(
        _ observer: T,
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, VirtualServiceError?) -> Void
    ) -> VirtualToken {
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

        return VirtualToken {
            timer.invalidate()
        }
    }

    @discardableResult
    public func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, Location?, VirtualServiceError?) -> Void
    ) -> VirtualToken {

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

        return VirtualToken {
            timer.invalidate()
        }
    }

    public func loadCurrentLocationData(
        from provider: VirtualProvider
    ) -> Future<(Location, VirtualData), VirtualServiceError> {
        let promise = Promise<(Location, VirtualData), VirtualServiceError>()
        let coordinate = locationManager.getCurrentLocation()
        coordinate.on(success: { [weak self] (coordinate) in
            self?.loadCurrentLocationData(
                for: coordinate,
                provider: provider,
                with: promise
            )
        }, failure: { (error) in
            promise.fail(error: .ruuviCore(error))
        })
        return promise.future
    }

    private func loadCurrentLocationData(
        for coordinate: CLLocation,
        provider: VirtualProvider,
        with promise: Promise<(Location, VirtualData), VirtualServiceError>
    ) {
        let location = locationService.reverseGeocode(coordinate: coordinate.coordinate)
        location.on(success: { [weak self] locations in
            guard let location = locations.last else {
                promise.fail(error: .failedToReverseGeocodeCoordinate)
                return
            }

            guard let op = self?.loadData(coordinate: location.coordinate, provider: provider) else {
                promise.fail(error: .callerDeinitedDuringOperation)
                return
            }

            op.on(success: { (data) in
                promise.succeed(value: (location, data))
            }, failure: { (error) in
                promise.fail(error: error)
            })

        }, failure: { (error) in
            promise.fail(error: .ruuviLocation(error))
        })
    }

    public func loadData(
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider
    ) -> Future<VirtualData, VirtualServiceError> {
        let promise = Promise<VirtualData, VirtualServiceError>()
        switch provider {
        case .openWeatherMap:
            let api = self.owmApi.loadCurrent(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude
            )
            api.on(success: { data in
                var celsius: Double?
                if let kelvin = data.kelvin {
                    celsius = kelvin - 273.15
                }
                let result = VirtualData(
                    celsius: celsius,
                    relativeHumidity: data.humidity,
                    hPa: data.pressure
                )
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: .openWeatherMap(error))
            })
        }
        return promise.future
    }

}
