import Foundation
import Future

protocol RuuviTagTank {
    // entities
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>

    // records
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError>
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError>
}
