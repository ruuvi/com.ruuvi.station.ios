import Foundation
import RuuviPersistence
import RuuviLocal

public protocol RuuviPoolFactory {
    func create(
        sqlite: RuuviPersistence,
        realm: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) -> RuuviPool
}

public final class RuuviPoolFactoryCoordinator: RuuviPoolFactory {
    public init() {}

    public func create(
        sqlite: RuuviPersistence,
        realm: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) -> RuuviPool {
        return RuuviPoolCoordinator(
            sqlite: sqlite,
            realm: realm,
            idPersistence: idPersistence,
            settings: settings,
            connectionPersistence: connectionPersistence
        )
    }
}
