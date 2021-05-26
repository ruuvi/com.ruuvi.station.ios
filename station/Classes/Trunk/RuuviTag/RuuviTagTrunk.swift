import Foundation
import Future
import RuuviOntology

protocol RuuviTagTrunk {
    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RUError>

    func readOne(_ id: String) -> Future<AnyRuuviTagSensor, RUError>
    func readAll(_ id: String) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll(_ id: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readAll() -> Future<[RuuviTagSensor], RUError>
    func readLast(_ id: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError>
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError>
    func getStoredTagsCount() -> Future<Int, RUError>
    func getStoredMeasurementsCount() -> Future<Int, RUError>
    // sensor settings
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RUError>
    func updateOffsetCorrection(type: OffsetCorrectionType,
                                with value: Double?,
                                of ruuviTag: RuuviTagSensor,
                                lastOriginalRecord record: RuuviTagSensorRecord?) -> Future<SensorSettings, RUError>
}
