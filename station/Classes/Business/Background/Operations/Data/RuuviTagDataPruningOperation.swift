import Foundation

class RuuviTagDataPruningOperation: AsyncOperation {

    private var id: String
    private var settings: Settings
    private var ruuviTagTank: RuuviTagTank

    init(id: String, ruuviTagTank: RuuviTagTank, settings: Settings) {
        self.id = id
        self.ruuviTagTank = ruuviTagTank
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        ruuviTagTank.deleteAll(id: id, before: date).on(failure: { error in
            print(error.localizedDescription)
        }, completion: {
            self.state = .finished
        })
    }
}
