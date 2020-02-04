import Foundation

class BackgroundProcessServiceiOS12: BackgroundProcessService {

    var dataPruningOperationsManager: DataPruningOperationsManager!

    func register() {
        // do nothing, launch it for iOS 12 and earlier
    }

    func schedule() {
        // do nothing, launch it for iOS 12 and earlier
    }

    func launch() {
        let operations = dataPruningOperationsManager.ruuviTagPruningOperations()
                        + dataPruningOperationsManager.webTagPruningOperations()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperations(operations, waitUntilFinished: false)
    }
}
