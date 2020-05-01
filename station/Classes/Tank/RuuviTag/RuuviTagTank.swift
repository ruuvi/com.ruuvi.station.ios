import Foundation
import Future

protocol RuuviTagTank {
    func add(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func remove(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>

    func add(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
    func remove(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
}
