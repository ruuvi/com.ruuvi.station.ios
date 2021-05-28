import Foundation
import RuuviPool

class RuuviTagLoadDataOperation: AsyncOperation {

    var ruuviTagId: String
    var mac: String
    var error: RUError?
    var recordsCount: Int = 0
    private var since: Date
    private var until: Date?
    private var network: RuuviNetwork
    private var ruuviPool: RuuviPool
    private var networkPersistance: NetworkPersistence

    init(ruuviTagId: String,
         mac: String,
         since: Date,
         until: Date? = nil,
         network: RuuviNetwork,
         ruuviPool: RuuviPool,
         networkPersistance: NetworkPersistence) {
        self.ruuviTagId = ruuviTagId
        self.mac = mac
        self.since = since
        self.until = until
        self.network = network
        self.ruuviPool = ruuviPool
        self.networkPersistance = networkPersistance
    }

    override func main() {
        let op = network.load(ruuviTagId: ruuviTagId, mac: mac, since: since, until: until)
        let macId = mac.mac
        networkPersistance.setSyncStatus(.syncing, for: macId)
        op.on(success: { [weak self] records in
            guard !records.isEmpty else {
                self?.state = .finished
                self?.networkPersistance.setSyncStatus(.complete, for: macId)
                return
            }
            let persist = self?.ruuviPool.create(records)
            persist?.on(success: { _ in
                self?.recordsCount = records.count
                self?.networkPersistance.setSyncStatus(.complete, for: macId)
                self?.state = .finished
            }, failure: { error in
                self?.error = .ruuviPool(error)
                self?.networkPersistance.setSyncStatus(.onError, for: macId)
                self?.state = .finished
            })
        }, failure: { [weak self] error in
            self?.error = error
            self?.networkPersistance.setSyncStatus(.onError, for: macId)
            self?.state = .finished
        })
    }

}
