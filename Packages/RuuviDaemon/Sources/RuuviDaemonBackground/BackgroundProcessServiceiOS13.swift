import BackgroundTasks
import Foundation
import Future

@available(iOS 13, *)
public final class BackgroundProcessServiceiOS13: BackgroundProcessService {
    private let dataPruningOperationsManager: DataPruningOperationsManager
    private let dataPruning = "com.ruuvi.station.BackgroundProcessServiceiOS13.dataPruning"

    public init(dataPruningOperationsManager: DataPruningOperationsManager) {
        self.dataPruningOperationsManager = dataPruningOperationsManager
    }

    public func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: dataPruning, using: nil) { task in
            if let bgTask = task as? BGProcessingTask {
                self.handleDataPruning(task: bgTask)
            } else {
                fatalError()
            }
        }
    }

    public func schedule() {
        // History is retained indefinitely. Previously scheduled tasks are still
        // registered above so iOS can complete them safely without deleting data.
    }

    private func handleDataPruning(task: BGProcessingTask) {
        schedule()

        let ruuviTags = dataPruningOperationsManager.ruuviTagPruningOperations()
        ruuviTags.on(success: { ruuviTagOperations in
            let operations = ruuviTagOperations
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
