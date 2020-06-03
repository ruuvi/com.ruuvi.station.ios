import Foundation

protocol VirtualTagReactor {
    func observe(_ block: @escaping (ReactorChange<AnyVirtualTagSensor>) -> Void) -> RUObservationToken
}
