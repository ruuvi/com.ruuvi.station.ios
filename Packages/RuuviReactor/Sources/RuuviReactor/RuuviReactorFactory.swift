import Foundation
import RuuviContext
import RuuviPersistence

public protocol RuuviReactorFactory {
    func create(
        sqliteContext: SQLiteContext,
        realmContext: RealmContext,
        sqlitePersistence: RuuviPersistence,
        realmPersistence: RuuviPersistence
    ) -> RuuviReactor
}

public final class RuuviReactorFactoryImpl: RuuviReactorFactory {
    public init() {}

    public func create(
        sqliteContext: SQLiteContext,
        realmContext: RealmContext,
        sqlitePersistence: RuuviPersistence,
        realmPersistence: RuuviPersistence
    ) -> RuuviReactor {
        return RuuviReactorImpl(
            sqliteContext: sqliteContext,
            realmContext: realmContext,
            sqlitePersistence: sqlitePersistence,
            realmPersistence: realmPersistence
        )
    }
}
