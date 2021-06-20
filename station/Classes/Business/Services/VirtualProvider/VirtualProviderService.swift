import Foundation
import Future
import CoreLocation
import RuuviVirtual
import RuuviOntology

protocol VirtualProviderService {
    func loadData(coordinate: CLLocationCoordinate2D, provider: VirtualProvider) -> Future<VirtualData, RUError>
    func loadCurrentLocationData(from provider: VirtualProvider) -> Future<(Location, VirtualData), RUError>

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, Location?, RUError?) -> Void
    ) -> RUObservationToken

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
}
