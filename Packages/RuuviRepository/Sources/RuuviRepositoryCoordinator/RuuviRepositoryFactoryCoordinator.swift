import Foundation
import RuuviPool
import RuuviStorage

public final class RuuviRepositoryFactoryCoordinator: RuuviRepositoryFactory {
    public init() {}

    public func create(
        pool: RuuviPool,
        storage: RuuviStorage
    ) -> RuuviRepository {
        return RuuviRepositoryCoordinator(
            pool: pool,
            storage: storage
        )
    }
}
