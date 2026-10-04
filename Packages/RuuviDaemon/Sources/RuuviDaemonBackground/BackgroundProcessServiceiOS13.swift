import BackgroundTasks
import Foundation
import UIKit
import Future

@available(iOS 13, *)
public final class BackgroundProcessServiceiOS13: BackgroundProcessService {
    private let dataPruningOperationsManager: DataPruningOperationsManager
    private var foregroundToken: NSObjectProtocol?
    private let pruningQueue = OperationQueue()
    private let dataPruning = "com.ruuvi.station.BackgroundProcessServiceiOS13.dataPruning"

    public init(dataPruningOperationsManager: DataPruningOperationsManager) {
        self.dataPruningOperationsManager = dataPruningOperationsManager
        pruningQueue.maxConcurrentOperationCount = 1
        foregroundToken = NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pruneLocalHistory()
        }
        pruneLocalHistory()
    }

    deinit {
        if let foregroundToken { NotificationCenter.default.removeObserver(foregroundToken) }
    }

    private func pruneLocalHistory() {
        guard pruningQueue.operationCount == 0 else { return }
        dataPruningOperationsManager.ruuviTagPruningOperations().on(success: { [weak self] operations in
            self?.pruningQueue.addOperations(operations, waitUntilFinished: false)
        })
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
