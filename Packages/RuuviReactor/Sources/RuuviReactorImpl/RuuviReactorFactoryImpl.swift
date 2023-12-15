import Foundation
import RuuviContext
import RuuviPersistence

public final class RuuviReactorFactoryImpl: RuuviReactorFactory {
    public init() {}

    public func create(
        sqliteContext: SQLiteContext,
        sqlitePersistence: RuuviPersistence
    ) -> RuuviReactor {
        RuuviReactorImpl(
            sqliteContext: sqliteContext,
            sqlitePersistence: sqlitePersistence
        )
    }
}
