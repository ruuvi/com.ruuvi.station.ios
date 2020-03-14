import Foundation
import RealmSwift

class DataPruningOperationsManager {

    var settings: Settings!

    func webTagPruningOperations() -> [Operation] {
        var operations = [Operation]()
        let realm = try! Realm()
        let webTags = realm.objects(WebTagRealm.self)
        for webTag in webTags {
            let operation = WebTagDataPruningOperation(uuid: webTag.uuid,
                                                       settings: settings)
            operations.append(operation)
        }
        return operations
    }

    func ruuviTagPruningOperations() -> [Operation] {
        var operations = [Operation]()
        let realm = try! Realm()
        let ruuviTags = realm.objects(RuuviTagRealmImpl.self)
        for ruuviTag in ruuviTags {
            let operation = RuuviTagDataPruningOperation(uuid: ruuviTag.uuid,
                                                         settings: settings)
            operations.append(operation)
        }
        return operations
    }

}
