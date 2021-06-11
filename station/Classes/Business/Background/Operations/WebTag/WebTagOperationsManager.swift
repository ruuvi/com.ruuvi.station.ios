import Foundation
import RealmSwift
import RuuviService

class WebTagOperationsManager {
    var weatherProviderService: WeatherProviderService!
    var alertService: RuuviServiceAlert!
    var alertHandler: AlertService!
    var webTagPersistence: WebTagPersistence!

    func alertsPullOperations() -> [Operation] {
        var operations = [Operation]()
        let realm = try! Realm()
        let webTags = realm.objects(WebTagRealm.self)
        for webTag in webTags {
            if alertService.hasRegistrations(for: webTag) {
                if let location = webTag.location?.location {
                    let operation = WebTagRefreshDataOperation(
                        sensor: webTag.struct,
                        location: location,
                        provider: webTag.provider,
                        weatherProviderService: weatherProviderService,
                        alertService: alertHandler,
                        webTagPersistence: webTagPersistence
                    )
                    operations.append(operation)
                } else {
                    let operation = CurrentWebTagRefreshDataOperation(
                        sensor: webTag.struct,
                        provider: webTag.provider,
                        weatherProviderService: weatherProviderService,
                        alertService: alertHandler,
                        webTagPersistence: webTagPersistence
                    )
                    operations.append(operation)
                }
            }
        }
        return operations
    }
}
