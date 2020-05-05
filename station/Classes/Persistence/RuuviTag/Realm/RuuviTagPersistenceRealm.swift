import RealmSwift
import Future
import BTKit
import Foundation

class RuuviTagPersistenceRealm: RuuviTagPersistence {

    var context: RealmContext!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .error)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        context.bgWorker.enqueue {
            do {
                let realmTag = RuuviTagRealm(ruuviTag: ruuviTag)
                try self.context.bg.write {
                    self.context.bg.add(realmTag, update: .modified)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac == nil)
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
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(record.mac == nil)
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
                    assert(record.mac == nil)
                    if let ruuviTag = self.context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: record.ruuviTagId) {
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
                                                  mac: ruuviTagRealm.mac,
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
                                            mac: ruuviTagRealm.mac,
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
            let result: [RuuviTagSensorRecord] = realmRecords.map { record in
                return RuuviTagSensorRecordStruct(ruuviTagId: ruuviTagId,
                                                  date: record.date,
                                                  mac: nil,
                                                  rssi: record.rssi.value,
                                                  temperature: record.unitTemperature,
                                                  humidity: record.unitHumidity,
                                                  pressure: record.unitPressure,
                                                  acceleration: record.acceleration,
                                                  voltage: record.unitVoltage,
                                                  movementCounter: record.movementCounter.value,
                                                  measurementSequenceNumber: record.measurementSequenceNumber.value,
                                                  txPower: record.txPower.value)
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        assert(ruuviTag.mac == nil)
        assert(ruuviTag.luid != nil)
        let promise = Promise<RuuviTagSensorRecord?, RUError>()
        guard let luid = ruuviTag.luid else {
            promise.fail(error: .unexpected(.attemptToReadDataFromRealmWithoutLUID))
            return promise.future
        }

        context.bgWorker.enqueue {
            let realmRecords = self.context.bg.objects(RuuviTagDataRealm.self)
                                   .filter("ruuviTag.uuid == %@", luid)
                                   .sorted(byKeyPath: "date", ascending: false)
            if let record = realmRecords.first {
                let result = RuuviTagSensorRecordStruct(ruuviTagId: luid.value,
                                                       date: record.date,
                                                       mac: nil,
                                                       rssi: record.rssi.value,
                                                       temperature: record.unitTemperature,
                                                       humidity: record.unitHumidity,
                                                       pressure: record.unitPressure,
                                                       acceleration: record.acceleration,
                                                       voltage: record.unitVoltage,
                                                       movementCounter: record.movementCounter.value,
                                                       measurementSequenceNumber: record.measurementSequenceNumber.value,
                                                       txPower: record.txPower.value)
                promise.succeed(value: result)
            } else {
                promise.succeed(value: nil)
            }
        }
        return promise.future
    }
}
