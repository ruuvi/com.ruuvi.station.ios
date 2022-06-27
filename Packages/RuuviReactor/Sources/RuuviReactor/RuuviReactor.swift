import Foundation
import RuuviOntology

public protocol RuuviReactor {
    func observe(
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void
    ) -> RuuviReactorToken

    func observe(
        _ luid: LocalIdentifier,
        _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void
    ) -> RuuviReactorToken

    func observeLast(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken

    func observeLatest(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken

    func observe(
        _ ruuviTag: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void
    ) -> RuuviReactorToken
}

public enum RuuviReactorChange<Type> {
    case initial([Type])
    case insert(Type)
    case delete(Type)
    case update(Type)
    case error(RuuviReactorError)
}

public final class RuuviReactorToken {
    private let cancellationClosure: () -> Void

    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    public func invalidate() {
        cancellationClosure()
    }
}
