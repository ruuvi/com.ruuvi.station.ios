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
    
}
