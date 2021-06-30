import Foundation
import RuuviPool
import RuuviStorage

public protocol RuuviRepositoryFactory {
    func create(
        pool: RuuviPool,
        storage: RuuviStorage
    ) -> RuuviRepository
}
