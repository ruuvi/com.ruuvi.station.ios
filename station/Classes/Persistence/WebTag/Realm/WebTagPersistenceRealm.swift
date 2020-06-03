import RealmSwift
import Future
import CoreLocation

class WebTagPersistenceRealm: WebTagPersistence {

    var context: RealmContext!

    func readAll() -> Future<[AnyVirtualTagSensor], RUError> {
        let promise = Promise<[AnyVirtualTagSensor], RUError>()
        context.bgWorker.enqueue {
            let realmEntities = self.context.bg.objects(WebTagRealm.self)
            let result: [AnyVirtualTagSensor] = realmEntities.map { webTagRealm in
                return VirtualTagSensorStruct(id: webTagRealm.uuid, name: webTagRealm.name).any
            }
            promise.succeed(value: result)
        }
        return promise.future
    }

    func readOne(_ id: String) -> Future<AnyVirtualTagSensor, RUError> {
        let promise = Promise<AnyVirtualTagSensor, RUError>()
        context.bgWorker.enqueue {
            if let webTagRealm = self.context.bg.object(ofType: WebTagRealm.self, forPrimaryKey: id) {
                let result = VirtualTagSensorStruct(id: webTagRealm.id, name: webTagRealm.name).any
                promise.succeed(value: result)
            } else {
                promise.fail(error: .unexpected(.failedToFindVirtualTag))
            }
        }
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
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

    func clearLocation(of webTag: WebTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if webTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        if let oldLocation = webTag.location {
                            self.context.bg.delete(oldLocation)
                        }
                        webTag.location = nil
                        webTag.name = WebTagLocationSource.current.title
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    if let oldLocation = webTag.location {
                        self.context.main.delete(oldLocation)
                    }
                    webTag.location = nil
                    webTag.name = WebTagLocationSource.current.title
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if webTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        if let oldLocation = webTag.location {
                            self.context.bg.delete(oldLocation)
                        }
                        let newLocation = WebTagLocationRealm(location: location)
                        self.context.bg.add(newLocation)
                        webTag.location = newLocation
                        webTag.name = location.city ?? location.country ?? WebTagLocationSource.manual.title
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    if let oldLocation = webTag.location {
                        self.context.main.delete(oldLocation)
                    }
                    let newLocation = WebTagLocationRealm(location: location)
                    self.context.main.add(newLocation, update: .all)
                    webTag.location = newLocation
                    webTag.name = location.city ?? location.country ?? WebTagLocationSource.manual.title
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func persist(provider: WeatherProvider, location: Location) -> Future<WeatherProvider, RUError> {
        let promise = Promise<WeatherProvider, RUError>()
        context.bgWorker.enqueue {
            let uuid = UUID().uuidString
            let webTag = WebTagRealm(uuid: uuid, provider: provider)
            webTag.name = location.city ?? location.country ?? WebTagLocationSource.manual.title
            let webTagLocation = WebTagLocationRealm(location: location)
            do {
                try self.context.bg.write {
                    self.context.bg.add(webTag, update: .all)
                    self.context.bg.add(webTagLocation, update: .modified)
                    webTag.location = webTagLocation
                }
                promise.succeed(value: provider)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func persist(provider: WeatherProvider) -> Future<WeatherProvider, RUError> {
        let promise = Promise<WeatherProvider, RUError>()
        context.bgWorker.enqueue {
            let uuid = UUID().uuidString
            let webTag = WebTagRealm(uuid: uuid, provider: provider)
            webTag.name = WebTagLocationSource.current.title
            do {
                try self.context.bg.write {
                    self.context.bg.add(webTag, update: .all)
                }
                promise.succeed(value: provider)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func remove(webTag: WebTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if webTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        self.context.bg.delete(webTag)
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    self.context.main.delete(webTag)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    func update(name: String, of webTag: WebTagRealm) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if webTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        webTag.name = name
                    }
                    promise.succeed(value: true)
                } catch {
                    promise.fail(error: .persistence(error))
                }
            }
        } else {
            do {
                try context.main.write {
                    webTag.name = name
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }

    @discardableResult
    func persist(currentLocation: Location, data: WPSData) -> Future<WPSData, RUError> {
        let promise = Promise<WPSData, RUError>()
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
    func persist(location: Location, data: WPSData) -> Future<WPSData, RUError> {
        let promise = Promise<WPSData, RUError>()
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
