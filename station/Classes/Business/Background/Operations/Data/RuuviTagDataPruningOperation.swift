import Foundation
import RealmSwift

class RuuviTagDataPruningOperation: AsyncOperation {

    private var uuid: String
    private var settings: Settings

    init(uuid: String, settings: Settings) {
        self.uuid = uuid
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        autoreleasepool {
            let realm = try! Realm()
            if let ruuviTag = realm.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid) {
                let points = ruuviTag.data.filter("date < %@", date)
                do {
                    try realm.write {
                        realm.delete(points)
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
            realm.refresh()
            realm.invalidate()
        }
        state = .finished
    }
}
