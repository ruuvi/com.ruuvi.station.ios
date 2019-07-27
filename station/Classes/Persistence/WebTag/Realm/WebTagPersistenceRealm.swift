import RealmSwift
import Future

class WebTagPersistenceRealm: WebTagPersistence {
    
    var context: RealmContext!
    
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
}
