import Foundation
import Future

protocol RuuviTagTank {
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
    func delete(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
}
