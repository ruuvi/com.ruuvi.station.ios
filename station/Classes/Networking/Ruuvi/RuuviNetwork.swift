import Foundation
import Future

protocol RuuviNetwork {
    func load(uuid: String, mac: String, isConnectable: Bool) -> Future<[RuuviTagProtocol],RUError>
}
