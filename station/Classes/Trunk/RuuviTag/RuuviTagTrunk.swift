import Foundation
import Future

protocol RuuviTagTrunk {
    func readOne(_ id: String) -> Future<AnyRuuviTagSensor, RUError>
    func readAll(_ id: String) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll(_ id: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll() -> Future<[RuuviTagSensor], RUError>
    func readLast(_ id: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError>
    func getStoredTagsCount() -> Future<Int, RUError>
    func getStoredMeasurementsCount() -> Future<Int, RUError>
}
