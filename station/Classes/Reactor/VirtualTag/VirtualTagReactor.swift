import Foundation
import RuuviOntology

protocol VirtualTagReactor {
    func observe(_ block: @escaping (ReactorChange<AnyVirtualTagSensor>) -> Void) -> RUObservationToken
}

enum ReactorChange<Type> {
    case initial([Type])
    case insert(Type)
    case delete(Type)
    case update(Type)
    case error(RUError)
}
