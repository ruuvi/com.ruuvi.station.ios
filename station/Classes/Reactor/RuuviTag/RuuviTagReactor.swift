import Foundation

protocol RuuviTagReactor {
    func observe(_ block: @escaping (ReactorChange<RuuviTagSensor>) -> Void) -> RUObservationToken
    func observe(_ ruuviTagId: String,
                 _ block: @escaping (ReactorChange<RuuviTagSensorRecord>) -> Void) -> RUObservationToken
}

enum ReactorChange<Type> {
    case initial([Type])
    case insert(Type)
    case delete(Type)
    case update(Type)
    case error(RUError)
}
