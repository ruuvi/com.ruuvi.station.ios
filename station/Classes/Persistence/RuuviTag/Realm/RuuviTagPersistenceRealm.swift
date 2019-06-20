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
    
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError> {
        let promise = Promise<RuuviTag,RUError>()
        context.bgWorker.enqueue {
            do {
                if let existingTag = self.fetch(uuid: ruuviTag.uuid) {
                    try self.context.bg.write {
                        if existingTag.isInvalidated {
                            let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                            self.context.bg.add(realmTag, update: .all)
                        } else {
                            existingTag.name = name
                            if existingTag.version != ruuviTag.version {
                                existingTag.version = ruuviTag.version
                            }
                            if existingTag.mac != ruuviTag.mac {
                                existingTag.mac = ruuviTag.mac
                            }
                        }
                    }
                } else {
                    let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                    try self.context.bg.write {
                        self.context.bg.add(realmTag, update: .all)
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
    
    func update(humidityOffset: Double, of ruuviTag: RuuviTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        ruuviTag.humidityOffset = humidityOffset
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
}
