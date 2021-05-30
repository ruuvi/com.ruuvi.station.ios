import Foundation
import Future
import RuuviOntology

protocol VirtualTagTrunk {
    func readOne(_ id: String) -> Future<AnyVirtualTagSensor, RUError>
    func readAll() -> Future<[AnyVirtualTagSensor], RUError>
}
