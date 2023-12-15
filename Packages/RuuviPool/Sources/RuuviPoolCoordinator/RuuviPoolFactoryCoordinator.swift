import Foundation
import RuuviLocal
import RuuviPersistence

public final class RuuviPoolFactoryCoordinator: RuuviPoolFactory {
    public init() {}

    public func create(
        sqlite: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) -> RuuviPool {
        RuuviPoolCoordinator(
            sqlite: sqlite,
            idPersistence: idPersistence,
            settings: settings,
            connectionPersistence: connectionPersistence
        )
    }
}
