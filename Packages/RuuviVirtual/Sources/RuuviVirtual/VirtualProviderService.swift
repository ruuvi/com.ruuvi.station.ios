import Foundation
import Future
import CoreLocation
import RuuviVirtual
import RuuviOntology

public protocol VirtualProviderService {
    func loadData(
        coordinate: CLLocationCoordinate2D,
        provider: VirtualProvider
    ) -> Future<VirtualData, VirtualServiceError>

    func loadCurrentLocationData(
        from provider: VirtualProvider
    ) -> Future<(Location, VirtualData), VirtualServiceError>

    @discardableResult
    func observeCurrentLocationData<T: AnyObject>(
        _ observer: T,
        provider: VirtualProvider,
        interval: TimeInterval,
        fire: Bool,
        closure: @escaping (T, VirtualData?, Location?, VirtualServiceError?) -> Void
    ) -> VirtualToken

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
}

public final class VirtualToken {
    private let cancellationClosure: () -> Void

    init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    public func invalidate() {
        cancellationClosure()
    }
}
