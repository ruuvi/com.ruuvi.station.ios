import Foundation
import Future
import CoreLocation
import RuuviLocal
import RuuviVirtual
import RuuviOntology

public final class VirtualServiceImpl: VirtualService {
    private let ruuviLocalImages: RuuviLocalImages
    private let virtualPersistence: VirtualPersistence
    private let weatherProviderService: VirtualProviderService

    public init(
        ruuviLocalImages: RuuviLocalImages,
        virtualPersistence: VirtualPersistence,
        virtualProviderService: VirtualProviderService
    ) {
        self.ruuviLocalImages = ruuviLocalImages
        self.virtualPersistence = virtualPersistence
        self.weatherProviderService = virtualProviderService
    }

    public var isCurrentLocationVirtualTagExists: Bool {
        return virtualPersistence.isCurrentLocationVirtualTagExists
    }

    public func add(provider: VirtualProvider, location: Location) -> Future<AnyVirtualTagSensor, VirtualServiceError> {
        let promise = Promise<AnyVirtualTagSensor, VirtualServiceError>()
        virtualPersistence.persist(
            provider: provider,
            location: location
        ).on(success: { virtualSensor in
            promise.succeed(value: virtualSensor)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    public func add(
        provider: VirtualProvider,
        name: String
    ) -> Future<AnyVirtualTagSensor, VirtualServiceError> {
        let promise = Promise<AnyVirtualTagSensor, VirtualServiceError>()
        virtualPersistence.persist(
            provider: provider,
            name: name
        ).on(success: { virtualSensor in
            promise.succeed(value: virtualSensor)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    public func remove(sensor: VirtualSensor) -> Future<Bool, VirtualServiceError> {
        ruuviLocalImages.deleteCustomBackground(for: sensor.id.luid)
        let promise = Promise<Bool, VirtualServiceError>()
        virtualPersistence.remove(sensor: sensor)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

    public func update(name: String, of sensor: VirtualSensor) -> Future<Bool, VirtualServiceError> {
        let promise = Promise<Bool, VirtualServiceError>()
        virtualPersistence.update(name: name, of: sensor)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

    public func update(location: Location, of sensor: VirtualSensor) -> Future<Bool, VirtualServiceError> {
        let promise = Promise<Bool, VirtualServiceError>()
        virtualPersistence.update(
            location: location,
            of: sensor
        ).on(success: { success in
            promise.succeed(value: success)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    public func clearLocation(of sensor: VirtualSensor, name: String) -> Future<Bool, VirtualServiceError> {
        let promise = Promise<Bool, VirtualServiceError>()
        virtualPersistence.clearLocation(
            of: sensor,
            name: name
        ).on(success: { success in
            promise.succeed(value: success)
        }, failure: { error in
            promise.fail(error: .virtualPersistence(error))
        })
        return promise.future
    }

    @discardableResult
    public func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool = true,
        closure: @escaping (T, VirtualData?, Location?, VirtualServiceError?) -> Void
    ) -> VirtualToken {
        return weatherProviderService.observeCurrentLocationData(
            observer,
            provider: provider,
            interval: interval,
            fire: fire,
            closure: closure
        )
    }

    @discardableResult
    public func observeData<T: AnyObject>(
        _ observer: T,
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool = true,
        closure: @escaping (T, VirtualData?, VirtualServiceError?) -> Void
    ) -> VirtualToken {
        return weatherProviderService.observeData(
            observer,
            coordinate: coordinate,
            provider: provider,
            interval: interval,
            fire: fire,
            closure: closure
        )
    }
}
