import Future
import Foundation
import RuuviOntology

protocol RuuviTagPersistence {
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError>
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError>
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError>
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError>
    func readAll() -> Future<[AnyRuuviTagSensor], RUError>
    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError>
    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RUError>
    func getStoredTagsCount() -> Future<Int, RUError>
    func getStoredMeasurementsCount() -> Future<Int, RUError>

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RUError>

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RUError>
    func updateOffsetCorrection(type: OffsetCorrectionType,
                                with value: Double?,
                                of ruuviTag: RuuviTagSensor,
                                lastOriginalRecord record: RuuviTagSensorRecord?) -> Future<SensorSettings, RUError>
    func delelteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RUError>
}
