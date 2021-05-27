import Future
import Foundation
import RuuviOntology

protocol RuuviStoragePersistence {
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError>
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError>
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError>
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviStorageError>
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviStorageError>
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviStorageError>
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviStorageError>
    func readAll() -> Future<[AnyRuuviTagSensor], RuuviStorageError>
    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviStorageError>
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError>
    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviStorageError>
    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviStorageError>
    func getStoredTagsCount() -> Future<Int, RuuviStorageError>
    func getStoredMeasurementsCount() -> Future<Int, RuuviStorageError>

    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviStorageError>

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviStorageError>
    func updateOffsetCorrection(type: OffsetCorrectionType,
                                with value: Double?,
                                of ruuviTag: RuuviTagSensor,
                                lastOriginalRecord record: RuuviTagSensorRecord?) -> Future<SensorSettings, RuuviStorageError>
    func delelteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviStorageError>
}
