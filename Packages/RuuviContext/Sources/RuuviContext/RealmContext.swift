import RealmSwift

public protocol RealmContext {
    var bg: Realm! { get }
    var main: Realm { get }
    var bgWorker: Worker { get }
}

public protocol RealmContextFactory {
    func create() -> RealmContext
}
