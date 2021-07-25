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
