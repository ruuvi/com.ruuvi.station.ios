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
        // Also protect against an operation created before pruning was disabled.
        state = .finished
    }
}
