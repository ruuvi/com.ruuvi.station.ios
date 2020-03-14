import RealmSwift
import Future
import BTKit
import Foundation

class RuuviTagPersistenceRealm: RuuviTagPersistence {

    var context: RealmContext!

    @discardableResult
    func persist(ruuviTagData: RuuviTagDataRealm, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    realm.add(ruuviTagData, update: .modified)
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    @discardableResult
    func persist(ruuviTag: RuuviTagRealm, data: RuuviTag) -> Future<RuuviTag, RUError> {
        let promise = Promise<RuuviTag, RUError>()
        if ruuviTag.realm == context.bg,
            let existingTag = ruuviTag as? RuuviTagRealmImpl {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: data)
                        try self.context.bg.write {
                            self.context.bg.add(tagData)
                        }
                        promise.succeed(value: data)
                    }
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try autoreleasepool {
                    guard let existingTag = ruuviTag as? RuuviTagRealmImpl else {
                        throw RUError.persistence(RUError.unexpected(.callbackErrorAndResultAreNil))

                    }
                    let tagData = RuuviTagDataRealm(ruuviTag: existingTag, data: data)
                    try ruuviTag.realm?.write {
                        self.context.main.add(tagData)
                    }
                    promise.succeed(value: data)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future

    }

    func persist(ruuviTag: RuuviTag,
                 name: String,
                 humidityOffset: Double,
                 humidityOffsetDate: Date?) -> Future<RuuviTag, RUError> {
        let promise = Promise<RuuviTag, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
                    if let existingTag = self.fetch(uuid: ruuviTag.uuid) {
                        try self.context.bg.write {
                            if existingTag.isInvalidated {
                                let realmTag = RuuviTagRealmImpl(ruuviTag: ruuviTag, name: name)
                                realmTag.humidityOffset = humidityOffset
                                realmTag.humidityOffsetDate = humidityOffsetDate
                                self.context.bg.add(realmTag, update: .all)
                                let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                                self.context.bg.add(tagData)
                            } else {
                                guard let tag = existingTag as? RuuviTagRealmImpl else {
                                    promise.fail(error: .persistence(RUError.unexpected(.callbackErrorAndResultAreNil)))
                                    return
                                }
                                tag.name = name
                                tag.humidityOffset = humidityOffset
                                tag.humidityOffsetDate = humidityOffsetDate
                                if tag.version != ruuviTag.version {
                                    tag.version = ruuviTag.version
                                }
                                if tag.mac != ruuviTag.mac {
                                    tag.mac = ruuviTag.mac
                                }
                                let tagData = RuuviTagDataRealm(ruuviTag: tag, data: ruuviTag)
                                self.context.bg.add(tagData)
                            }
                        }
                    } else {
                        let realmTag = RuuviTagRealmImpl(ruuviTag: ruuviTag, name: name)
                        realmTag.humidityOffset = humidityOffset
                        realmTag.humidityOffsetDate = humidityOffsetDate
                        let tagData = RuuviTagDataRealm(ruuviTag: realmTag, data: ruuviTag)
                        try self.context.bg.write {
                            self.context.bg.add(realmTag, update: .all)
                            self.context.bg.add(tagData)
                        }
                    }
                    promise.succeed(value: ruuviTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }

    func delete(ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            self.context.bg.delete(ruuviTag)
                        }
                        promise.succeed(value: true)
                    }
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

    func clearHumidityCalibration(of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.humidityOffset = 0
                            ruuviTag.humidityOffsetDate = nil
                        }
                        promise.succeed(value: true)
                    }
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

    private func fetch(uuid: String) -> RuuviTagRealm? {
        return context.bg.object(ofType: RuuviTagRealmImpl.self, forPrimaryKey: uuid)
    }

    func persist(logs: [RuuviTagEnvLogFull], for uuid: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
                    if let existingTag = self.fetch(uuid: uuid) {
                        try self.context.bg.write {
                            if !existingTag.isInvalidated,
                                let existingTag = existingTag as? RuuviTagRealmImpl {
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
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }

    func clearHistory(uuid: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        context.bgWorker.enqueue {
            do {
                try autoreleasepool {
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
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }

        return promise.future
    }
}

// MARK: - Update
extension RuuviTagPersistenceRealm {
    @discardableResult
    func update(mac: String?, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.mac = mac
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func update(humidityOffset: Double, date: Date, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.humidityOffset = humidityOffset
                            ruuviTag.humidityOffsetDate = date
                        }
                        promise.succeed(value: true)
                    }
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

    func update(name: String, of ruuviTag: RuuviTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try autoreleasepool {
                        try self.context.bg.write {
                            ruuviTag.name = name
                        }
                        promise.succeed(value: true)
                    }
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

    @discardableResult
    func update(isConnectable: Bool, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.isConnectable = isConnectable
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    @discardableResult
    func update(version: Int, of ruuviTag: RuuviTagRealm, realm: Realm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try autoreleasepool {
                try realm.write {
                    ruuviTag.version = version
                }
                promise.succeed(value: true)
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
}
