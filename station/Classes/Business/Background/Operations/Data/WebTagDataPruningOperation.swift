import Foundation

class WebTagDataPruningOperation: AsyncOperation {

    private var webTag: WebTagRealm
    private var settings: Settings

    init(webTag: WebTagRealm, settings: Settings) {
        self.webTag = webTag
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        let points = webTag.data.filter("date < ", date)
        if let realm = webTag.realm {
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
