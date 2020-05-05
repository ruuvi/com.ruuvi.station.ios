import Foundation
import Future

protocol VirtualTagTrunk {
    func readOne(_ id: String) -> Future<AnyVirtualTagSensor, RUError>
    func readAll() -> Future<[AnyVirtualTagSensor], RUError>
}
