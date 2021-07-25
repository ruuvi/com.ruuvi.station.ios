import Foundation
import RuuviOntology

public protocol VirtualReactor {
    func observe(
        _ block: @escaping (VirtualReactorChange<AnyVirtualTagSensor>) -> Void
    ) -> VirtualReactorToken

    func observeLast(
        _ virtualTag: VirtualTagSensor,
        _ block: @escaping (VirtualReactorChange<AnyVirtualTagSensorRecord?>) -> Void
    ) -> VirtualReactorToken
}

public enum VirtualReactorChange<Type> {
    case initial([Type])
    case insert(Type)
    case delete(Type)
    case update(Type)
    case error(VirtualReactorError)
}

public final class VirtualReactorToken {
    private let cancellationClosure: () -> Void

    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    public func invalidate() {
        cancellationClosure()
    }
}
