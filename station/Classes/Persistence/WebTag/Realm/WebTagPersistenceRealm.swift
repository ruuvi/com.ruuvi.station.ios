import RealmSwift
import Future

class WebTagPersistenceRealm: WebTagPersistence {
    
    var context: RealmContext!
    
    func update(location: Location, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
        if webTag.realm == context.bg {
            context.bgWorker.enqueue {
                do {
                    try self.context.bg.write {
                        if let oldLocation = webTag.location {
                            self.context.bg.delete(oldLocation)
                        }
                        let newLocation = WebTagLocationRealm()
                        newLocation.city = location.city
                        newLocation.country = location.country
                        newLocation.latitude = location.coordinate.latitude
                        newLocation.longitude = location.coordinate.longitude
                        self.context.bg.add(newLocation)
                        webTag.location = newLocation
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
                    let newLocation = WebTagLocationRealm()
                    newLocation.city = location.city
                    newLocation.country = location.country
                    newLocation.latitude = location.coordinate.latitude
                    newLocation.longitude = location.coordinate.longitude
                    self.context.main.add(newLocation)
                    webTag.location = newLocation
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .persistence(error))
            }
        }
        return promise.future
    }
    
    func persist(provider: WeatherProvider) -> Future<WeatherProvider,RUError> {
        let promise = Promise<WeatherProvider,RUError>()
        context.bgWorker.enqueue {
            let uuid = UUID().uuidString
            let webTag = WebTagRealm(uuid: uuid, provider: provider)
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
    
    func remove(webTag: WebTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
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
    
    func update(name: String, of webTag: WebTagRealm) -> Future<Bool,RUError> {
        let promise = Promise<Bool,RUError>()
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
}
