import Foundation
import RuuviPool
import RuuviStorage

public protocol RuuviRepositoryFactory {
    func create(
        pool: RuuviPool,
        storage: RuuviStorage
    ) -> RuuviRepository
}

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
