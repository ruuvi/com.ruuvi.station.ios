import RealmSwift
import Future
import CoreLocation
import RuuviOntology
import RuuviContext
import RuuviLocal
import RuuviVirtual
#if canImport(RuuviVirtualModel)
import RuuviVirtualModel
#endif

// swiftlint:disable:next type_body_length
public final class VirtualPersistenceRealm: VirtualPersistence {
    private let context: RealmContext
    private var settings: RuuviLocalSettings

    public init(context: RealmContext, settings: RuuviLocalSettings) {
        self.context = context
        self.settings = settings
    }

    public var isCurrentLocationVirtualTagExists: Bool {
        return context.main.objects(WebTagRealm.self)
            .filter("location == nil").count > 0
    }

    public func readLast(
        _ virtualTag: VirtualTagSensor
    ) -> Future<VirtualTagSensorRecord?, VirtualPersistenceError> {
        let promise = Promise<VirtualTagSensorRecord?, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let lastRecord = self.context.bg.objects(WebTagDataRealm.self)
                .filter("webTag.uuid == %@", virtualTag.id)
                .sorted(byKeyPath: "date", ascending: false)
                .first
            promise.succeed(value: lastRecord?.record?.any)
        }
        return promise.future
    }

    public func readAll() -> Future<[AnyVirtualTagSensor], VirtualPersistenceError> {
        let promise = Promise<[AnyVirtualTagSensor], VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let realmEntities = self.context.bg.objects(WebTagRealm.self)
            let result: [AnyVirtualTagSensor] = realmEntities.map { webTagRealm in
                return VirtualTagSensorStruct(
                    id: webTagRealm.uuid,
                    name: webTagRealm.name,
                    loc: webTagRealm.loc,
                    provider: webTagRealm.provider
                ).any
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    public func readOne(_ id: String) -> Future<AnyVirtualTagSensor, VirtualPersistenceError> {
        let promise = Promise<AnyVirtualTagSensor, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            if let webTagRealm = self.context.bg.object(ofType: WebTagRealm.self, forPrimaryKey: id) {
                let result = VirtualTagSensorStruct(
                    id: webTagRealm.id,
                    name: webTagRealm.name,
                    loc: webTagRealm.loc,
                    provider: webTagRealm.provider
                ).any
                promise.succeed(value: result)
            } else {
                promise.fail(error: .failedToFindVirtualTag)
            }
        }
        return promise.future
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, VirtualPersistenceError> {
        let promise = Promise<Bool, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            do {
                let data = self.context.bg.objects(WebTagDataRealm.self)
                               .filter("webTag.uuid == %@ AND date < %@", ruuviTagId, date)
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

    public func clearLocation(
        of sensor: VirtualSensor,
        name: String
    ) -> Future<Bool, VirtualPersistenceError> {
        let promise = Promise<Bool, VirtualPersistenceError>()
        let webTagId = sensor.id
        context.bgWorker.enqueue {
            do {
                if let webTag = self.context.bg.object(ofType: WebTagRealm.self, forPrimaryKey: webTagId) {
                    try self.context.bg.write {
                        if let oldLocation = webTag.location {
                            self.context.bg.delete(oldLocation)
                        }
                        webTag.location = nil
                        webTag.name = name
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindVirtualTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    public func update(
        location: Location,
        of sensor: VirtualSensor
    ) -> Future<Bool, VirtualPersistenceError> {
        let promise = Promise<Bool, VirtualPersistenceError>()
        let webTagId = sensor.id
        context.bgWorker.enqueue {
            do {
                if let webTag = self.context.bg.object(ofType: WebTagRealm.self, forPrimaryKey: webTagId) {
                    try self.context.bg.write {
                        if let oldLocation = webTag.location {
                            self.context.bg.delete(oldLocation)
                        }
                        let newLocation = WebTagLocationRealm(location: location)
                        self.context.bg.add(newLocation, update: .all)
                        webTag.location = newLocation
                        webTag.name = location.city ?? location.country ?? ""
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindVirtualTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    public func persist(
        provider: VirtualProvider,
        location: Location
    ) -> Future<VirtualProvider, VirtualPersistenceError> {
        let promise = Promise<VirtualProvider, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let uuid = UUID().uuidString
            let webTag = WebTagRealm(uuid: uuid, provider: provider)
            webTag.name = location.city ?? location.country ?? ""
            let webTagLocation = WebTagLocationRealm(location: location)
            do {
                try self.context.bg.write {
                    self.context.bg.add(webTag, update: .all)
                    self.context.bg.add(webTagLocation, update: .modified)
                    webTag.location = webTagLocation
                }
                self.settings.tagsSorting.append(uuid)
                promise.succeed(value: provider)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    public func persist(provider: VirtualProvider, name: String) -> Future<VirtualProvider, VirtualPersistenceError> {
        let promise = Promise<VirtualProvider, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let uuid = UUID().uuidString
            let webTag = WebTagRealm(uuid: uuid, provider: provider)
            webTag.name = name
            do {
                try self.context.bg.write {
                    self.context.bg.add(webTag, update: .all)
                }
                self.settings.tagsSorting.append(uuid)
                promise.succeed(value: provider)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    public func remove(sensor: VirtualSensor) -> Future<Bool, VirtualPersistenceError> {
        let promise = Promise<Bool, VirtualPersistenceError>()
        let sensorId = sensor.id
        context.bgWorker.enqueue {
            do {
                if let webTag = self.context.bg.object(
                    ofType: WebTagRealm.self,
                    forPrimaryKey: sensorId
                ) {
                    try self.context.bg.write {
                        self.context.bg.delete(webTag)
                    }
                    self.settings.tagsSorting.removeAll(where: { $0 == sensorId })
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindVirtualTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    public func update(
        name: String,
        of sensor: VirtualSensor
    ) -> Future<Bool, VirtualPersistenceError> {
        let promise = Promise<Bool, VirtualPersistenceError>()
        let webTagId = sensor.id
        context.bgWorker.enqueue {
            do {
                if let webTag = self.context.bg.object(ofType: WebTagRealm.self, forPrimaryKey: webTagId) {
                    try self.context.bg.write {
                        webTag.name = name
                    }
                    promise.succeed(value: true)
                } else {
                    promise.fail(error: .failedToFindVirtualTag)
                }
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    @discardableResult
    public func persist(currentLocation: Location, data: VirtualData) -> Future<VirtualData, VirtualPersistenceError> {
        let promise = Promise<VirtualData, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let currentLocationWebTags = self.context.bg.objects(WebTagRealm.self).filter("location == nil")
            do {
                try currentLocationWebTags.forEach({ (webTag) in
                    if !webTag.isInvalidated {
                        let tagData = WebTagDataRealm(webTag: webTag, data: data)
                        let location = WebTagLocationRealm(location: currentLocation)
                        try self.context.bg.write {
                            if !webTag.isInvalidated {
                                self.context.bg.add(location, update: .modified)
                                tagData.location = location
                                self.context.bg.add(tagData)
                            }
                        }
                    }
                })
                promise.succeed(value: data)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    @discardableResult
    public func persist(location: Location, data: VirtualData) -> Future<VirtualData, VirtualPersistenceError> {
        let promise = Promise<VirtualData, VirtualPersistenceError>()
        context.bgWorker.enqueue {
            let webTags = self.context.bg.objects(WebTagRealm.self)
                .filter("location != nil AND location.latitude == %@ AND location.longitude == %@",
                        location.coordinate.latitude,
                        location.coordinate.longitude)
            do {
                try webTags.forEach({ (webTag) in
                    if !webTag.isInvalidated {
                        let tagData = WebTagDataRealm(webTag: webTag, data: data)
                        let location = WebTagLocationRealm(location: location)
                        try self.context.bg.write {
                            if !webTag.isInvalidated {
                                self.context.bg.add(location, update: .modified)
                                tagData.location = location
                                self.context.bg.add(tagData)
                            }
                        }
                    }
                })
                promise.succeed(value: data)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
}
