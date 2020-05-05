import Foundation
import Future

protocol RuuviTagTank {
    // entities
    @discardableResult
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    @discardableResult
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    @discardableResult
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>

    // records
    @discardableResult
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
    @discardableResult
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError>
}
