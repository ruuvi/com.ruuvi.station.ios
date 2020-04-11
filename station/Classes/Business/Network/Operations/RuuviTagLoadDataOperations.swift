import Foundation

class RuuviTagLoadDataOperation: AsyncOperation {

    var uuid: String
    var error: RUError?
    private var mac: String
    private var isConnectable: Bool
    private var network: RuuviNetwork
    private var persistence: RuuviTagPersistence

    init(uuid: String,
         mac: String,
         isConnectable: Bool,
         network: RuuviNetwork,
         persistence: RuuviTagPersistence) {
        self.uuid = uuid
        self.mac = mac
        self.isConnectable = isConnectable
        self.network = network
        self.persistence = persistence
    }

    override func main() {
        let uuid = self.uuid
        let op = network.load(uuid: uuid, mac: mac, isConnectable: isConnectable)
        op.on(success: { [weak self] data in
            let persist = self?.persistence.persist(data: data, for: uuid)
            persist?.on(success: { success in
                self?.state = .finished
            }, failure: { error in
                self?.error = error
                self?.state = .finished
            })
        }, failure: { [weak self] error in
            self?.error = error
            self?.state = .finished
        })
    }

}
