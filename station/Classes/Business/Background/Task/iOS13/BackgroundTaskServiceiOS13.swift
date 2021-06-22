import Foundation
import BackgroundTasks

@available(iOS 13, *)
class BackgroundTaskServiceiOS13: BackgroundTaskService {

    var webTagOperationsManager: WebTagOperationsManager!

    private let networkTagRefresh = "com.ruuvi.station.BackgroundTaskServiceiOS13.webTagRefresh"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: networkTagRefresh, using: nil) { task in
            if let bgTask = task as? BGAppRefreshTask {
                self.handleWebTagRefresh(task: bgTask)
            } else {
                fatalError()
            }
        }
    }

    func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: networkTagRefresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    private func handleWebTagRefresh(task: BGAppRefreshTask) {
        schedule()
        webTagOperationsManager.alertsPullOperations()
            .on(success: { [weak self] operations in
                self?.enqueueOperations(operations, task: task)
            })
    }

    private func enqueueOperations(_ operations: [Operation], task: BGAppRefreshTask) {
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
    }
}
