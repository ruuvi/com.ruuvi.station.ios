import Foundation
import RealmSwift

class WebTagOperationsManager {

    var weatherProviderService: WeatherProviderService!
    var alertService: AlertService!
    var webTagPersistence: WebTagPersistence!

    func alertsPullOperations() -> [Operation] {
        var operations = [Operation]()
        let realm = try! Realm()
        let webTags = realm.objects(WebTagRealm.self)
        for webTag in webTags {
            if alertService.hasRegistrations(for: webTag.uuid) {
                if let location = webTag.location?.location {
                    let operation = WebTagRefreshDataOperation(uuid: webTag.uuid,
                                                               location: location,
                                                               provider: webTag.provider,
                                                               weatherProviderService: weatherProviderService,
                                                               alertService: alertService,
                                                               webTagPersistence: webTagPersistence)
                    operations.append(operation)
                } else {
                    let operation = CurrentWebTagRefreshDataOperation(uuid: webTag.uuid,
                                                                      provider: webTag.provider,
                                                                      weatherProviderService: weatherProviderService,
                                                                      alertService: alertService,
                                                                      webTagPersistence: webTagPersistence)
                    operations.append(operation)
                }
            }
        }
        return operations
    }
}
