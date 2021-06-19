import RealmSwift
import RuuviContext

public final class RealmContextFactoryImpl: RealmContextFactory {
    public init() {}

    public func create() -> RealmContext {
        return RealmContextImpl()
    }
}
