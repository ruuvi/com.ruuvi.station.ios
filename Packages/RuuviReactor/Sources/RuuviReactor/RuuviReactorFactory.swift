#if SWIFT_PACKAGE
    import RuuviOntology
#endif
import Foundation
import RuuviAnalytics
import RuuviContext
import RuuviPersistence

public protocol RuuviReactorFactory {
    func create(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence,
        errorReporter: RuuviErrorReporter
    ) -> RuuviReactor
}
