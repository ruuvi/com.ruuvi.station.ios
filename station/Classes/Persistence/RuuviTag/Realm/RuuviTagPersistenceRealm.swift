import RealmSwift
import Future
import BTKit
import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// swiftlint:disable:next type_body_length
class RuuviTagPersistenceRealm: RuuviTagPersistence {
    var context: RealmContext!
    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .error)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .modified)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let realmTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTag.id) {
                    try self.context.bg.write {
                        self.context.bg.delete(realmTag)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                let data = self.context.bg.objects(RuuviTagDataRealm.self)
                    .filter("ruuviTag.uuid == %@", ruuviTagId)
                try self.context.bg.write {
                    self.context.bg.delete(data)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                let data = self.context.bg.objects(RuuviTagDataRealm.self)
                    .filter("ruuviTag.uuid == %@ AND date < %@", ruuviTagId, date)
                try self.context.bg.write {
                    self.context.bg.delete(data)
                }
                promise.succeed(value: true)
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(record.macId == nil)
        context.bgWorker.enqueue {
            do {
                if let ruuviTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: record.ruuviTagId) {
                    let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                    try self.context.bg.write {
                        self.context.bg.add(data, update: .all)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                var failed = false
                for record in records {
                    assert(record.macId == nil)
                    let extractedExpr: RuuviTagRealm? = self.context.bg
                        .object(ofType: RuuviTagRealm.self,
                                forPrimaryKey: record.ruuviTagId)
                    if let ruuviTag = extractedExpr {
                        let data = RuuviTagDataRealm(ruuviTag: ruuviTag, record: record)
                        try self.context.bg.write {
                            self.context.bg.add(data, update: .all)
                        }
                    } else {
                        failed = true
                    }
                }
                if failed {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                } else {
                    promise.succeed(value: true)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RUError> {
        let promise = Promise<AnyRuuviTagSensor, RUError>()
        context.bgWorker.enqueue {
            if let ruuviTagRealm = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: ruuviTagId) {
                let result = RuuviTagSensorStruct(version: ruuviTagRealm.version,
                                                  luid: ruuviTagRealm.uuid.luid,
                                                  macId: ruuviTagRealm.mac?.mac,
                                                  isConnectable: ruuviTagRealm.isConnectable,
                                                  name: ruuviTagRealm.name).any
                promise.succeed(value: result)
            } else {
                promise.fail(error: .unexpected(.failedToFindRuuviTag))
            }
        }
        return promise.future
    }
    
    func readAll() -> Future<[AnyRuuviTagSensor], RUError> {
        let promise = Promise<[AnyRuuviTagSensor], RUError>()
        context.bgWorker.enqueue {
            let realmEntities = self.context.bg.objects(RuuviTagRealm.self)
            let result: [AnyRuuviTagSensor] = realmEntities.map { ruuviTagRealm in
                return RuuviTagSensorStruct(version: ruuviTagRealm.version,
                                            luid: ruuviTagRealm.uuid.luid,
                                            macId: ruuviTagRealm.mac?.mac,
                                            isConnectable: ruuviTagRealm.isConnectable,
                                            name: ruuviTagRealm.name).any
            }
            promise.succeed(value: result)
        }
        return promise.future
    }
    
    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", ruuviTagId)
                .sorted(byKeyPath: "date")
            let result: [RuuviTagSensorRecord] = realmRecords.map { realmRecord in
                return RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                  date: realmRecord.date,
                                                  macId: nil,
                                                  rssi: realmRecord.rssi.value,
                                                  temperature: realmRecord.unitTemperature,
                                                  humidity: realmRecord.unitHumidity,
                                                  pressure: realmRecord.unitPressure,
                                                  acceleration: realmRecord.acceleration,
                                                  voltage: realmRecord.unitVoltage,
                                                  movementCounter: realmRecord.movementCounter.value,
                                                  measurementSequenceNumber: realmRecord.measurementSequenceNumber.value,
                                                  txPower: realmRecord.txPower.value,
                                                  temperatureOffset: realmRecord.temperatureOffset,
                                                  humidityOffset: realmRecord.humidityOffset,
                                                  pressureOffset: realmRecord.pressureOffset)
            }
            promise.succeed(value: result)
        }
        return promise.future
    }
    
    func readAll(_ ruuviTagId: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        context.bgWorker.enqueue {
            let ruuviTagDataRealms = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", ruuviTagId)
                .sorted(byKeyPath: "date")
            var results: [RuuviTagSensorRecord] = []
            var previousDate = ruuviTagDataRealms.first?.date ?? Date()
            for ruuviTagDataRealm in ruuviTagDataRealms {
                autoreleasepool {
                    guard ruuviTagDataRealm.date >= previousDate.addingTimeInterval(interval) else {
                        return
                    }
                    previousDate = ruuviTagDataRealm.date
                    results.append(
                        RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                   date: ruuviTagDataRealm.date,
                                                   macId: nil,
                                                   rssi: ruuviTagDataRealm.rssi.value,
                                                   temperature: ruuviTagDataRealm.unitTemperature,
                                                   humidity: ruuviTagDataRealm.unitHumidity,
                                                   pressure: ruuviTagDataRealm.unitPressure,
                                                   acceleration: ruuviTagDataRealm.acceleration,
                                                   voltage: ruuviTagDataRealm.unitVoltage,
                                                   movementCounter: ruuviTagDataRealm.movementCounter.value,
                                                   measurementSequenceNumber: ruuviTagDataRealm.measurementSequenceNumber.value,
                                                   txPower: ruuviTagDataRealm.txPower.value,
                                                   temperatureOffset: ruuviTagDataRealm.temperatureOffset,
                                                   humidityOffset: ruuviTagDataRealm.humidityOffset,
                                                   pressureOffset: ruuviTagDataRealm.pressureOffset))
                }
            }
            promise.succeed(value: results)
        }
        return promise.future
    }
    
    func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@ AND date > %@", ruuviTagId, date)
                .sorted(byKeyPath: "date")
            var results: [RuuviTagSensorRecord] = []
            var previousDate = realmRecords.first?.date ?? Date()
            for realmRecord in realmRecords {
                autoreleasepool {
                    guard realmRecord.date >= previousDate.addingTimeInterval(interval) else {
                        return
                    }
                    previousDate = realmRecord.date
                    results.append(
                        RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                   date: realmRecord.date,
                                                   macId: nil,
                                                   rssi: realmRecord.rssi.value,
                                                   temperature: realmRecord.unitTemperature,
                                                   humidity: realmRecord.unitHumidity,
                                                   pressure: realmRecord.unitPressure,
                                                   acceleration: realmRecord.acceleration,
                                                   voltage: realmRecord.unitVoltage,
                                                   movementCounter: realmRecord.movementCounter.value,
                                                   measurementSequenceNumber: realmRecord.measurementSequenceNumber.value,
                                                   txPower: realmRecord.txPower.value,
                                                   temperatureOffset: realmRecord.temperatureOffset,
                                                   humidityOffset: realmRecord.humidityOffset,
                                                   pressureOffset: realmRecord.pressureOffset))
                }
            }
            promise.succeed(value: results)
        }
        return promise.future
    }
    
    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        context.bgWorker.enqueue {
            let realmRecords = self.context.bg
                .objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@ AND date > %@",
                        ruuviTagId,
                        Date(timeIntervalSince1970: from))
                .sorted(byKeyPath: "date")
            let result: [RuuviTagSensorRecord] = realmRecords.map { record in
                return RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                  date: record.date,
                                                  macId: nil,
                                                  rssi: record.rssi.value,
                                                  temperature: record.unitTemperature,
                                                  humidity: record.unitHumidity,
                                                  pressure: record.unitPressure,
                                                  acceleration: record.acceleration,
                                                  voltage: record.unitVoltage,
                                                  movementCounter: record.movementCounter.value,
                                                  measurementSequenceNumber: record.measurementSequenceNumber.value,
                                                  txPower: record.txPower.value,
                                                  temperatureOffset: record.temperatureOffset,
                                                  humidityOffset: record.humidityOffset,
                                                  pressureOffset: record.pressureOffset)
            }
            promise.succeed(value: result)
        }
        return promise.future
    }
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        let promise = Promise<RuuviTagSensorRecord?, RUError>()
        guard ruuviTag.macId == nil,
              let luid = ruuviTag.luid else {
            promise.fail(error: .unexpected(.attemptToReadDataFromRealmWithoutLUID))
            return promise.future
        }
        context.bgWorker.enqueue {
            if let lastRecord = self.context.bg.objects(RuuviTagDataRealm.self)
                .filter("ruuviTag.uuid == %@", luid.value)
                .sorted(byKeyPath: "date", ascending: false)
                .first {
                let sequenceNumber = lastRecord.measurementSequenceNumber.value
                let lastRecordResult = RuuviTagSensorRecordStruct(ruuviTagId: luid.value,
                                                        date: lastRecord.date,
                                                        macId: nil,
                                                        rssi: lastRecord.rssi.value,
                                                        temperature: lastRecord.unitTemperature,
                                                        humidity: lastRecord.unitHumidity,
                                                        pressure: lastRecord.unitPressure,
                                                        acceleration: lastRecord.acceleration,
                                                        voltage: lastRecord.unitVoltage,
                                                        movementCounter: lastRecord.movementCounter.value,
                                                        measurementSequenceNumber: sequenceNumber,
                                                        txPower: lastRecord.txPower.value,
                                                        temperatureOffset: lastRecord.temperatureOffset,
                                                        humidityOffset: lastRecord.humidityOffset,
                                                        pressureOffset: lastRecord.pressureOffset)
                promise.succeed(value: lastRecordResult)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }
}
// MARK: - Private
extension RuuviTagPersistenceRealm {
    func reportToCrashlytics(error: Error, method: String = #function, line: Int = #line) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("\(method)(line: \(line)")
        Crashlytics.crashlytics().record(error: error)
        #endif
    }
}

extension RuuviTagPersistenceRealm {
    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RUError> {
        let promise = Promise<SensorSettings?, RUError>()
        guard ruuviTag.macId == nil,
              let _ = ruuviTag.luid else {
            promise.fail(error: .unexpected(.attemptToReadDataFromRealmWithoutLUID))
            return promise.future
        }
        context.bgWorker.enqueue {
            if let record = self.context.bg.objects(SensorSettingsRealm.self)
                .first(where: { $0.tagId == ruuviTag.luid?.value }) {
                promise.succeed(value: record.sensorSettings)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }
    
    func updateOffsetCorrection(type: OffsetCorrectionType,
                                with value: Double?,
                                of ruuviTag: RuuviTagSensor,
                                lastOriginalRecord record: RuuviTagSensorRecord?) -> Future<SensorSettings, RUError> {
        let promise = Promise<SensorSettings, RUError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let record = self.context.bg.objects(SensorSettingsRealm.self)
                    .first(where: { $0.tagId == ruuviTag.luid?.value }) {
                    try self.context.bg.write {
                        switch type {
                        case .humidity:
                            record.humidityOffset.value = value
                            record.humidityOffsetDate = value == nil ? nil : Date()
                        case .pressure:
                            record.pressureOffset.value = value
                            record.pressureOffsetDate = value == nil ? nil : Date()
                        default:
                            record.temperatureOffset.value = value
                            record.temperatureOffsetDate = value == nil ? nil : Date()
                        }
                    }
                    promise.succeed(value: record.sensorSettings)
                } else {
                    let sensorSettingsRealm = SensorSettingsRealm(ruuviTag: ruuviTag)
                    switch type {
                    case .humidity:
                        sensorSettingsRealm.humidityOffset.value = value
                        sensorSettingsRealm.humidityOffsetDate = value == nil ? nil : Date()
                    case .pressure:
                        sensorSettingsRealm.pressureOffset.value = value
                        sensorSettingsRealm.pressureOffsetDate = value == nil ? nil : Date()
                    default:
                        sensorSettingsRealm.temperatureOffset.value = value
                        sensorSettingsRealm.temperatureOffsetDate = value == nil ? nil : Date()
                    }
                    try self.context.bg.write {
                        self.context.bg.add(sensorSettingsRealm, update: .error)
                    }
                    promise.succeed(value: sensorSettingsRealm.sensorSettings)
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func delelteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                if let sensorSettingRealm = self.context.bg.objects(SensorSettingsRealm.self)
                    .first(where: { $0.tagId == ruuviTag.luid?.value }) {
                    try self.context.bg.write {
                        self.context.bg.delete(sensorSettingRealm)
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .unexpected(.failedToFindRuuviTag))
                }
            } catch {
                self.reportToCrashlytics(error: error)
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
}
