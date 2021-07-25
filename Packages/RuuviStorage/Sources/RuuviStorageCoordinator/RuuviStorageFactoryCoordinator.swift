import Foundation
import RuuviPersistence
import RuuviStorage

public final class RuuviStorageFactoryCoordinator: RuuviStorageFactory {
    public init() {}

    public func create(realm: RuuviPersistence, sqlite: RuuviPersistence) -> RuuviStorage {
        return RuuviStorageCoordinator(sqlite: sqlite, realm: realm)
    }
}
