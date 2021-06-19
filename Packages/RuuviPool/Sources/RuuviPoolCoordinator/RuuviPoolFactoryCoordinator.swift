import Foundation
import RuuviPool
import RuuviLocal
import RuuviPersistence

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
