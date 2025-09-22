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
        let date = Calendar.current.date(
            byAdding: .hour,
            value: -offset,
            to: Date()
        ) ?? Date()
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await ruuviPool.deleteAllRecords(id, before: date)
            } catch {
                print("[DataPruningOperation] deleteAllRecords failed: \(error)")
            }
            self.state = .finished
        }
    }
}
