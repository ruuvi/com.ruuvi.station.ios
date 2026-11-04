#if SWIFT_PACKAGE
    import RuuviStorage
    import RuuviOntology
#endif
import Foundation
import RuuviPersistence

public final class RuuviStorageFactoryCoordinator: RuuviStorageFactory {
    public init() {}

    public func create(sqlite: RuuviPersistence) -> RuuviStorage {
        RuuviStorageCoordinator(sqlite: sqlite)
    }
}
