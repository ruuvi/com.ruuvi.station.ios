import Foundation
import Future
import RuuviOntology

public protocol RuuviPool {
    // entities
    @discardableResult
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError>

    // records
    @discardableResult
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError>
    @discardableResult
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPoolError>
}
