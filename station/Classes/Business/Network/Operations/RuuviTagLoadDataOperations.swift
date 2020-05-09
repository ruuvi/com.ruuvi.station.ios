import Foundation

class RuuviTagLoadDataOperation: AsyncOperation {

    var ruuviTagId: String
    var mac: String
    var error: RUError?
    private var isConnectable: Bool
    private var network: RuuviNetwork
    private var ruuviTagTank: RuuviTagTank

    init(ruuviTagId: String,
         mac: String,
         isConnectable: Bool,
         network: RuuviNetwork,
         ruuviTagTank: RuuviTagTank) {
        self.ruuviTagId = ruuviTagId
        self.mac = mac
        self.isConnectable = isConnectable
        self.network = network
        self.ruuviTagTank = ruuviTagTank
    }

    override func main() {
        let op = network.load(ruuviTagId: ruuviTagId,
        mac: mac, isConnectable: isConnectable)
        op.on(success: { [weak self] records in
            let persist = self?.ruuviTagTank.create(records)
            persist?.on(success: { _ in
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
