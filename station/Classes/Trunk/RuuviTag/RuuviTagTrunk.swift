import Foundation
import Future

protocol RuuviTagTrunk {
    func readAll() -> Future<[RuuviTagSensor], RUError>
}
