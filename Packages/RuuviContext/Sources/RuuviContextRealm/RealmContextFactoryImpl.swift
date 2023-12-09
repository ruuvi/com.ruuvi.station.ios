import RuuviContext

public final class RealmContextFactoryImpl: RealmContextFactory {
    public init() {}

    public func create() -> RealmContext {
        RealmContextImpl()
    }
}
