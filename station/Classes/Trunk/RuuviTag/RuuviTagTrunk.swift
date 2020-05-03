import Foundation
import Future

protocol RuuviTagTrunk {
    func readAll() -> Future<[RuuviTagSensor], RUError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError>
}
