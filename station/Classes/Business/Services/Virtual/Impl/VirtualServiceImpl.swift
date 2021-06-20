import Foundation
import Future
import CoreLocation
import RuuviLocal
import RuuviVirtual
import RuuviOntology

class VirtualServiceImpl: VirtualService {
    var ruuviLocalImages: RuuviLocalImages!
    var virtualPersistence: VirtualPersistence!
    var weatherProviderService: VirtualProviderService!

    func add(provider: VirtualProvider, location: Location) -> Future<VirtualProvider, RUError> {
        let promise = Promise<VirtualProvider, RUError>()
        virtualPersistence.persist(
            provider: provider,
            location: location,
            name: VirtualLocation.manual.title
        ).on(success: { provider in
            promise.succeed(value: provider)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    func add(provider: VirtualProvider) -> Future<VirtualProvider, RUError> {
        let promise = Promise<VirtualProvider, RUError>()
        virtualPersistence.persist(
            provider: provider,
            name: VirtualLocation.current.title
        ).on(success: { provider in
            promise.succeed(value: provider)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    func remove(sensor: VirtualSensor) -> Future<Bool, RUError> {
        ruuviLocalImages.deleteCustomBackground(for: sensor.id.luid)
        let promise = Promise<Bool, RUError>()
        virtualPersistence.remove(sensor: sensor)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

    func update(name: String, of sensor: VirtualSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        virtualPersistence.update(name: name, of: sensor)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

    func update(location: Location, of sensor: VirtualSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        virtualPersistence.update(
            location: location,
            of: sensor,
            name: VirtualLocation.manual.title
        ).on(success: { success in
            promise.succeed(value: success)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    func clearLocation(of sensor: VirtualSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        virtualPersistence.clearLocation(
            of: sensor,
            name: VirtualLocation.current.title
        ).on(success: { success in
            promise.succeed(value: success)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(_ observer: T,
                                                  provider: VirtualProvider,
                                                  interval: TimeInterval,
                                                  fire: Bool = true,
                                                  closure: @escaping (T, VirtualData?, Location?, RUError?) -> Void)
        -> RUObservationToken {
        return weatherProviderService.observeCurrentLocationData(observer,
                                                                 provider: provider,
                                                                 interval: interval,
                                                                 fire: fire,
                                                                 closure: closure)
    }

    @discardableResult
    func observeData<T: AnyObject>(_ observer: T,
                                   coordinate: CLLocationCoordinate2D,
                                   provider: VirtualProvider,
                                   interval: TimeInterval,
                                   fire: Bool = true,
                                   closure: @escaping (T, VirtualData?, RUError?) -> Void) -> RUObservationToken {
        return weatherProviderService.observeData(observer,
                                                  coordinate: coordinate,
                                                  provider: provider,
                                                  interval: interval,
                                                  fire: fire,
                                                  closure: closure)
    }
}
