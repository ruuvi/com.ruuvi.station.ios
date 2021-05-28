import Foundation
import RuuviLocal

class RuuviTagDataPruningOperation: AsyncOperation {

    private var id: String
    private var settings: RuuviLocalSettings
    private var ruuviTagTank: RuuviTagTank

    init(id: String, ruuviTagTank: RuuviTagTank, settings: RuuviLocalSettings) {
        self.id = id
        self.ruuviTagTank = ruuviTagTank
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        ruuviTagTank.deleteAllRecords(id, before: date).on(failure: { error in
            print(error.localizedDescription)
        }, completion: {
            self.state = .finished
        })
    }
}
