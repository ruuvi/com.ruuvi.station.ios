import BackgroundTasks
import Foundation

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

        Task {
            do {
                let operations = try await dataPruningOperationsManager.ruuviTagPruningOperations()
                if operations.isEmpty {
                    task.setTaskCompleted(success: true)
                } else {
                    startDataPruning(operations, task: task)
                }
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
    }

    private func startDataPruning(
        _ operations: [Operation],
        task: BGProcessingTask
    ) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        guard let lastOperation = operations.last else {
            task.setTaskCompleted(success: true)
            return
        }

        lastOperation.completionBlock = {
            task.setTaskCompleted(success: !lastOperation.isCancelled)
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }
}
