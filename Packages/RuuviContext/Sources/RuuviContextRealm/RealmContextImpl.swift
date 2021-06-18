import RuuviContext
import RealmSwift

class RealmContextImpl: RealmContext {
    var main: Realm = try! Realm()
    var bg: Realm!
    var bgWorker: Worker = Worker()

    init() {
        bgWorker.enqueue {
            self.bg = try! Realm()
        }
    }
}
