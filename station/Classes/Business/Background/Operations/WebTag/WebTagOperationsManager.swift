import Foundation
import RealmSwift

class WebTagOperationsManager {

    var weatherProviderService: WeatherProviderService!
    var alertService: AlertService!

    func alertsPullOperations() -> [Operation] {
        var operations = [Operation]()
        let realm = try! Realm()
        let webTags = realm.objects(WebTagRealm.self)
        for webTag in webTags {
            if alertService.hasRegistrations(for: webTag.uuid) {
                if let location = webTag.location {
                    let operation = WebTagRefreshDataOperation(uuid: webTag.uuid,
                                                               latitude: location.latitude,
                                                               longitude: location.longitude,
                                                               provider: webTag.provider,
                                                               weatherProviderService: weatherProviderService,
                                                               alertService: alertService)
                    operations.append(operation)
                } else {
                    let operation = CurrentWebTagRefreshDataOperation(uuid: webTag.uuid,
                                                                      provider: webTag.provider,
                                                                      weatherProviderService: weatherProviderService,
                                                                      alertService: alertService)
                    operations.append(operation)
                }
            }
        }
        return operations
    }
}
