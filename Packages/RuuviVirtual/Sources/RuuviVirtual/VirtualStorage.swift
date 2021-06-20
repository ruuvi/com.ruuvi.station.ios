import Foundation
import Future
import RuuviOntology

public protocol VirtualStorage {
    func readOne(_ id: String) -> Future<AnyVirtualTagSensor, VirtualStorageError>
    func readAll() -> Future<[AnyVirtualTagSensor], VirtualStorageError>
}
