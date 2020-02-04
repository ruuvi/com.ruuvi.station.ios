import Foundation

class RuuviTagDataPruningOperation: AsyncOperation {

    private var ruuviTag: RuuviTagRealm
    private var settings: Settings

    init(ruuviTag: RuuviTagRealm, settings: Settings) {
        self.ruuviTag = ruuviTag
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        let points = ruuviTag.data.filter("date < ", date)
        if let realm = ruuviTag.realm {
            do {
                try realm.write {
                    realm.delete(points)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        state = .finished
    }
}
