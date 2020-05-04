import Foundation

class WebTagDataPruningOperation: AsyncOperation {

    private var id: String
    private var settings: Settings
    private var virtualTagTank: VirtualTagTank

    init(id: String, virtualTagTank: VirtualTagTank, settings: Settings) {
        self.id = id
        self.virtualTagTank = virtualTagTank
        self.settings = settings
    }

    override func main() {
        let offset = settings.dataPruningOffsetHours
        let date = Calendar.current.date(byAdding: .hour,
                                         value: -offset,
                                         to: Date()) ?? Date()
        virtualTagTank.deleteAll(id: id, before: date).on(failure: { error in
            print(error.localizedDescription)
        }, completion: {
            self.state = .finished
        })
    }
}
