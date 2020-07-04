import Foundation

protocol RuuviTagReactor {
    func observe(_ block: @escaping (ReactorChange<AnyRuuviTagSensor>) -> Void) -> RUObservationToken
    func observe(_ ruuviTagId: String,
                 _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RUObservationToken
    func observeLast(_ ruuviTag: RuuviTagSensor,
                     _ block: @escaping (ReactorChange<AnyRuuviTagSensorRecord?>) -> Void) -> RUObservationToken
}

enum ReactorChange<Type> {
    case initial([Type])
    case insert(Type)
    case delete(Type)
    case update(Type)
    case error(RUError)
}
