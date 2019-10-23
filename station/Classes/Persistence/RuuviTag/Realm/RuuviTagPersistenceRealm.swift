import RealmSwift
import Future
import BTKit

class RuuviTagPersistenceRealm: RuuviTagPersistence {
    var context: RealmContext!
    
    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        do {
            try realm.write {
                realm.add(ruuviTagData)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
    
    @discardableResult
    func update(mac: String?, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        do {
            try realm.write {
                ruuviTag.mac = mac
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
    
    @discardableResult
    func update(isConnectable: Bool, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        do {
            try realm.write {
                ruuviTag.isConnectable = isConnectable
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
    
    @discardableResult
    func update(version: Int, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        do {
            try realm.write {
                ruuviTag.version = version
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
    
    @discardableResult
    func persist(ruuviTag: RuuviTagRealm, data: RuuviTag) -> Future<RuuviTag,RUError> {
        let promise = Promise<RuuviTag,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    let tagData = RuuviTagDataRealm(ruuviTag: ruuviTag, data: data)
                    try self.context.bg.write {
                        self.context.bg.add(tagData)
                    }
                    promise.succeed(value: data)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                let tagData = RuuviTagDataRealm(ruuviTag: ruuviTag, data: data)
                try ruuviTag.realm?.write {
                    self.context.main.add(tagData)
                }
                promise.succeed(value: data)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
        
    }
    
    func persist(ruuviTag: RuuviTag, name: String, humidityOffset: Double, humidityOffsetDate: Date?) -> Future<RuuviTag,RUError> {
        let promise = Promise<RuuviTag,RUError>()
        context.bgWorker.enqueue {
            do {
                if let existingTag = self.fetch(uuid: ruuviTag.uuid) {
                    try self.context.bg.write {
                        if existingTag.isInvalidated {
                            let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                            realmTag.humidityOffset = humidityOffset
                            realmTag.humidityOffsetDate = humidityOffsetDate
                            self.context.bg.add(realmTag, update: .all)
                            let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                            self.context.bg.add(tagData)
                        } else {
                            existingTag.name = name
                            existingTag.humidityOffset = humidityOffset
                            existingTag.humidityOffsetDate = humidityOffsetDate
                            if existingTag.version != ruuviTag.version {
                                existingTag.version = ruuviTag.version
                            }
                            if existingTag.mac != ruuviTag.mac {
                                existingTag.mac = ruuviTag.mac
                            }
                            let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: ruuviTag)
                            self.context.bg.add(tagData)
                        }
                    }
                } else {
                    let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                    realmTag.humidityOffset = humidityOffset
                    realmTag.humidityOffsetDate = humidityOffsetDate
                    let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                    try self.context.bg.write {
                        self.context.bg.add(realmTag, update: .all)
                        self.context.bg.add(tagData)
                    }
                }
                promise.succeed(value: ruuviTag)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        
        return promise.future
    }
    
    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        self.context.bg.delete(ruuviTag)
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    self.context.main.delete(ruuviTag)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func clearHumidityCalibration(of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        ruuviTag.humidityOffset = 0
                        ruuviTag.humidityOffsetDate = nil
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.humidityOffset = 0
                    ruuviTag.humidityOffsetDate = nil
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func update(humidityOffset: Double, date: Date, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        ruuviTag.humidityOffset = humidityOffset
                        ruuviTag.humidityOffsetDate = date
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.humidityOffset = humidityOffset
                    ruuviTag.humidityOffsetDate = date
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        ruuviTag.name = name
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    ruuviTag.name = name
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    private func fetch(uuid: String) -> RuuviTagRealm? {
        return context.bg.object(ofType: RuuviTagRealm.self, forPrimaryKey: uuid)
    }
    
    func update(lastSyncDate: Date, for uuid: String) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
               context.bgWorker.enqueue {
                   do {
                       if let existingTag = self.fetch(uuid: uuid) {
                           try self.context.bg.write {
                               if !existingTag.isInvalidated {
                                   existingTag.logSyncDate = lastSyncDate
                                   promise.succeed(value: true)
                               } else {
                                   promise.fail(error: .core(.objectInvalidated))
                               }
                           }
                       } else {
                           promise.fail(error: .core(.objectNotFound))
                       }
                   } catch {
                       promise.fail(error: .persistence(error))
                   }
               }
               
               return promise.future
    }
    
    func persist(logs: [RuuviTagEnvLogFull], for uuid: String) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        context.bgWorker.enqueue {
            do {
                if let existingTag = self.fetch(uuid: uuid) {
                    try self.context.bg.write {
                        if !existingTag.isInvalidated {
                            for log in logs {
                                let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: log)
                                self.context.bg.add(tagData, update: .modified)
                            }
                            promise.succeed(value: true)
                        } else {
                            promise.fail(error: .core(.objectInvalidated))
                        }
                    }
                } else {
                    promise.fail(error: .core(.objectNotFound))
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        
        return promise.future
    }
    
    func clearHistory(uuid: String) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        context.bgWorker.enqueue {
            do {
                if let existingTag = self.fetch(uuid: uuid) {
                    try self.context.bg.write {
                        if !existingTag.isInvalidated {
                            self.context.bg.delete(existingTag.data)
                            promise.succeed(value: true)
                        } else {
                            promise.fail(error: .core(.objectInvalidated))
                        }
                    }
                } else {
                    promise.fail(error: .core(.objectNotFound))
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        
        return promise.future
    }
}
