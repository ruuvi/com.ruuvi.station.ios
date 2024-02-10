import Foundation
import RuuviAnalytics
import RuuviContext
import RuuviPersistence

public final class RuuviReactorFactoryImpl: RuuviReactorFactory {
    public init() {}

    public func create(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence,
        errorReporter: RuuviErrorReporter
    ) -> RuuviReactor {
        RuuviReactorImpl(
            sqliteContext: sqliteContext,
            sqlitePersistence: sqlitePersistence,
            errorReporter: errorReporter
        )
    }
}
