import Foundation
import Future

class BackgroundProcessServiceiOS12: BackgroundProcessService {

    var dataPruningOperationsManager: DataPruningOperationsManager!

    func register() {
        // do nothing, launch it for iOS 12 and earlier
    }

    func schedule() {
        // do nothing, launch it for iOS 12 and earlier
    }

    func launch() {
        let ruuviTags = dataPruningOperationsManager.ruuviTagPruningOperations()
        let virtualTags = dataPruningOperationsManager.webTagPruningOperations()
        Future.zip(ruuviTags, virtualTags).on(success: { (ruuviTagOperations, virtualTagsOperations) in
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = 1
            let operations = ruuviTagOperations + virtualTagsOperations
            queue.addOperations(operations, waitUntilFinished: false)
        })
    }
}
