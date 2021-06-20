import Foundation
import Future
import RuuviOntology

public final class VirtualStorageCoordinator: VirtualStorage {
    private let persistence: VirtualPersistence

    public init(persistence: VirtualPersistence) {
        self.persistence = persistence
    }

    public func readAll() -> Future<[AnyVirtualTagSensor], VirtualStorageError> {
        let promise = Promise<[AnyVirtualTagSensor], VirtualStorageError>()
        persistence.readAll()
            .on(success: { sensors in
                promise.succeed(value: sensors)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

    public func readOne(_ id: String) -> Future<AnyVirtualTagSensor, VirtualStorageError> {
        let promise = Promise<AnyVirtualTagSensor, VirtualStorageError>()
        persistence.readOne(id)
            .on(success: { sensor in
                promise.succeed(value: sensor)
            }, failure: { error in
                promise.fail(error: .virtualPersistence(error))
            })
        return promise.future
    }

}
