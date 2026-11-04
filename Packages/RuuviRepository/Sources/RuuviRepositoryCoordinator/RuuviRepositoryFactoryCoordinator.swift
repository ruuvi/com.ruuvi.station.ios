#if SWIFT_PACKAGE
    import RuuviRepository
    import RuuviOntology
#endif
import Foundation
import RuuviPool
import RuuviStorage

public final class RuuviRepositoryFactoryCoordinator: RuuviRepositoryFactory {
    public init() {}

    public func create(
        pool: RuuviPool,
        storage: RuuviStorage
    ) -> RuuviRepository {
        RuuviRepositoryCoordinator(
            pool: pool,
            storage: storage
        )
    }
}
