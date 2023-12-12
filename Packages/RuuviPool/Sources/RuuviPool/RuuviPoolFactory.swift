import Foundation
import RuuviLocal
import RuuviPersistence

public protocol RuuviPoolFactory {
    func create(
        sqlite: RuuviPersistence,
        realm: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) -> RuuviPool
}
