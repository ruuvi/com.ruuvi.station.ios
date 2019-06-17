import RealmSwift
import Future
import BTKit

class RuuviTagPersistenceRealm: RuuviTagPersistence {
    var context: RealmContext!
    
    func persist(ruuviTag: RuuviTag, name: String) -> Future<RuuviTag,RUError> {
        let promise = Promise<RuuviTag,RUError>()
        context.bgWorker.enqueue {
            do {
                if let existingTag = self.fetch(uuid: ruuviTag.uuid) {
                    try self.context.bg.write {
                        existingTag.name = name
                        if existingTag.version != ruuviTag.version {
                            existingTag.version = ruuviTag.version
                        }
                        if existingTag.mac != ruuviTag.mac {
                            existingTag.mac = ruuviTag.mac
                        }
                    }
                } else {
                    let realmTag = RuuviTagRealm(ruuviTag: ruuviTag, name: name)
                    try self.context.bg.write {
                        self.context.bg.add(realmTag)
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
