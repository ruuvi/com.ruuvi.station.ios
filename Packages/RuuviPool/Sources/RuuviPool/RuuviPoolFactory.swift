#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
import RuuviLocal
import RuuviPersistence

public protocol RuuviPoolFactory {
    func create(
        sqlite: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) -> RuuviPool
}
