import Foundation
import RuuviPool
import RuuviStorage
import RuuviRepository

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
