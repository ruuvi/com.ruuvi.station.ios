import Foundation
import BackgroundTasks
import Future

@available(iOS 13, *)
class BackgroundProcessServiceiOS13: BackgroundProcessService {

    var dataPruningOperationsManager: DataPruningOperationsManager!
    private let dataPruning = "com.ruuvi.station.BackgroundProcessServiceiOS13.dataPruning"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: dataPruning, using: nil) { task in
            if let bgTask = task as? BGProcessingTask {
                self.handleDataPruning(task: bgTask)
            } else {
                fatalError()
            }
        }
    }

    func schedule() {
        do {
            let request = BGProcessingTaskRequest(identifier: dataPruning)
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = false
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print(error)
        }
    }

    private func handleDataPruning(task: BGProcessingTask) {
        schedule()

        let ruuviTags = dataPruningOperationsManager.ruuviTagPruningOperations()
        let virtualTags = dataPruningOperationsManager.webTagPruningOperations()
        Future.zip(ruuviTags, virtualTags).on(success: { (ruuviTagOperations, virtualTagsOperations) in
            let operations = ruuviTagOperations + virtualTagsOperations
            if operations.count > 0 {
                let queue = OperationQueue()
                queue.maxConcurrentOperationCount = 1
                let lastOperation = operations.last!

                lastOperation.completionBlock = {
                    task.setTaskCompleted(success: !lastOperation.isCancelled)
                }

                queue.addOperations(operations, waitUntilFinished: false)

                task.expirationHandler = {
                    queue.cancelAllOperations()
                }
            } else {
                task.setTaskCompleted(success: true)
            }
        }, failure: { _ in
            task.setTaskCompleted(success: false)
        })
    }

}
