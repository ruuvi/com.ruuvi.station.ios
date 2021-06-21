import Foundation
import Future
import CoreLocation
import RuuviVirtual
import RuuviOntology

public protocol VirtualService {
    var isCurrentLocationVirtualTagExists: Bool { get }

    func add(
        provider: VirtualProvider,
        name: String
    ) -> Future<VirtualProvider, VirtualServiceError>

    func add(
        provider: VirtualProvider,
        location: Location
    ) -> Future<VirtualProvider, VirtualServiceError>

    func remove(
        sensor: VirtualSensor
    ) -> Future<Bool, VirtualServiceError>

    func update(
        name: String,
        of sensor: VirtualSensor
    ) -> Future<Bool, VirtualServiceError>

    func update(
        location: Location,
        of sensor: VirtualSensor
    ) -> Future<Bool, VirtualServiceError>

    func clearLocation(
        of sensor: VirtualSensor,
        name: String
    ) -> Future<Bool, VirtualServiceError>

    // swiftlint:disable function_parameter_count
    @discardableResult
    func observeData<T: AnyObject>(
        _ observer: T,
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, VirtualServiceError?) -> Void
    ) -> VirtualToken
    // swiftlint:enable function_parameter_count

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, Location?, VirtualServiceError?) -> Void
    ) -> VirtualToken
}
