import Foundation
import RealmSwift

class DataPruningOperationsManager {

    var realmContext: RealmContext!
    var settings: Settings!

    func webTagPruningOperations() -> [Operation] {
        var operations = [Operation]()
        let webTags = realmContext.main.objects(WebTagRealm.self)
        for webTag in webTags {
            let operation = WebTagDataPruningOperation(webTag: webTag,
                                                       settings: settings)
            operations.append(operation)
        }
        return operations
    }

    func ruuviTagPruningOperations() -> [Operation] {
        var operations = [Operation]()
        let ruuviTags = realmContext.main.objects(RuuviTagRealm.self)
        for ruuviTag in ruuviTags {
            let operation = RuuviTagDataPruningOperation(ruuviTag: ruuviTag,
                                                         settings: settings)
            operations.append(operation)
        }
        return operations
    }

}
