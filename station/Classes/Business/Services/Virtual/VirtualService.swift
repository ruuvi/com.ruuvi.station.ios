import Foundation
import Future
import CoreLocation
import RuuviVirtual
import RuuviOntology

protocol VirtualService {
    func add(provider: VirtualProvider) -> Future<VirtualProvider, RUError>
    func add(provider: VirtualProvider, location: Location) -> Future<VirtualProvider, RUError>
    func remove(sensor: VirtualSensor) -> Future<Bool, RUError>
    func update(name: String, of sensor: VirtualSensor) -> Future<Bool, RUError>
    func update(location: Location, of sensor: VirtualSensor) -> Future<Bool, RUError>
    func clearLocation(of sensor: VirtualSensor) -> Future<Bool, RUError>

    // swiftlint:disable function_parameter_count
    @discardableResult
    func observeData<T: AnyObject>(
        _ observer: T,
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, RUError?) -> Void
    ) -> RUObservationToken
    // swiftlint:enable function_parameter_count

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, Location?, RUError?) -> Void
    ) -> RUObservationToken
}
