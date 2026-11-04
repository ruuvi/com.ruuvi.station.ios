#if SWIFT_PACKAGE
    import RuuviDaemon
    import RuuviDaemonOperation
#endif
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
        // History is retained indefinitely. Previously scheduled tasks are still
        // registered above so iOS can complete them safely without deleting data.
    }

    private func handleDataPruning(task: BGProcessingTask) {
        // History retention has no pruning work. Complete legacy scheduled tasks exactly once.
        task.setTaskCompleted(success: true)
    }
}
