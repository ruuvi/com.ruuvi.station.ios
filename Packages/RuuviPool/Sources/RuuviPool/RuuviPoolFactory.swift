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
