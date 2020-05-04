import Foundation
import Future

protocol RuuviTagTrunk {
    func readOne(_ id: String) -> Future<AnyRuuviTagSensor, RUError>
    func readAll(_ id: String) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll() -> Future<[RuuviTagSensor], RUError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError>
}
