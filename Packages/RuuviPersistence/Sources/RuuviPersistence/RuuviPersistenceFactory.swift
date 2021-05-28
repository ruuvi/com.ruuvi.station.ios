import RuuviContext

public protocol RuuviPersistenceFactory {
    func create(realm: RealmContext) -> RuuviPersistence
    func create(sqlite: SQLiteContext) -> RuuviPersistence
}

public final class RuuviPersistenceFactoryImpl: RuuviPersistenceFactory {
    public init() {}

    public func create(realm: RealmContext) -> RuuviPersistence {
        return RuuviPersistenceRealm(context: realm)
    }

    public func create(sqlite: SQLiteContext) -> RuuviPersistence {
        return RuuviPersistenceSQLite(context: sqlite)
    }
}
