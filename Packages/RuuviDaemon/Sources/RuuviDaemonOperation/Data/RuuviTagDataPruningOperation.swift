import Foundation
import RuuviLocal
import RuuviPool

class RuuviTagDataPruningOperation: AsyncOperation {
    private var id: String
    private var settings: RuuviLocalSettings
    private var ruuviPool: RuuviPool

    init(id: String, ruuviPool: RuuviPool, settings: RuuviLocalSettings) {
        self.id = id
        self.ruuviPool = ruuviPool
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        ruuviPool.deleteAllRecords(id, before: date).on(failure: { error in
            print(error.localizedDescription)
        }, completion: {
            self.state = .finished
        })
    }
}
