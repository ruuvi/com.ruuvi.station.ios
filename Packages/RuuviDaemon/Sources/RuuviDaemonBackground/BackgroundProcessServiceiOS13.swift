import BackgroundTasks
import Foundation

@available(iOS 13, *)
protocol BackgroundProcessingRequesting: AnyObject {
    var requiresExternalPower: Bool { get set }
    var requiresNetworkConnectivity: Bool { get set }
}

@available(iOS 13, *)
protocol BackgroundProcessingTasking: AnyObject {
    var expirationHandler: (() -> Void)? { get set }
    func setTaskCompleted(success: Bool)
}

@available(iOS 13, *)
protocol BackgroundTaskScheduling {
    @discardableResult
    func register(
        identifier: String,
        launchHandler: @escaping (BackgroundProcessingTasking) -> Void
    ) -> Bool
    func makeRequest(identifier: String) -> BackgroundProcessingRequesting
    func submit(_ request: BackgroundProcessingRequesting) throws
}

@available(iOS 13, *)
protocol BackgroundOperationQueueing: AnyObject {
    var maxConcurrentOperationCount: Int { get set }
    func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool)
    func cancelAllOperations()
}

@available(iOS 13, *)
protocol PlatformBackgroundProcessingTasking: AnyObject {
    var expirationHandler: (() -> Void)? { get set }
    func setTaskCompleted(success: Bool)
}

@available(iOS 13, *)
extension BGProcessingTask: PlatformBackgroundProcessingTasking {}

@available(iOS 13, *)
protocol PlatformBackgroundTaskScheduling {
    @discardableResult
    func register(
        identifier: String,
        launchHandler: @escaping (PlatformBackgroundProcessingTasking) -> Void
    ) -> Bool
    func submit(_ request: BGProcessingTaskRequest) throws
}

@available(iOS 13, *)
struct LivePlatformBackgroundTaskScheduler: PlatformBackgroundTaskScheduling {
    private let registerClosure: (
        String,
        @escaping (PlatformBackgroundProcessingTasking) -> Void
    ) -> Bool
    private let submitClosure: (BGProcessingTaskRequest) throws -> Void

    init(
        registerClosure: @escaping (
            String,
            @escaping (PlatformBackgroundProcessingTasking) -> Void
        ) -> Bool = { identifier, launchHandler in
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: identifier,
                using: nil
            ) { task in
                guard let processingTask = task as? BGProcessingTask else {
                    fatalError()
                }
                launchHandler(processingTask)
            }
        },
        submitClosure: @escaping (BGProcessingTaskRequest) throws -> Void = { request in
            try BGTaskScheduler.shared.submit(request)
        }
    ) {
        self.registerClosure = registerClosure
        self.submitClosure = submitClosure
    }

    @discardableResult
    func register(
        identifier: String,
        launchHandler: @escaping (PlatformBackgroundProcessingTasking) -> Void
    ) -> Bool {
        registerClosure(identifier, launchHandler)
    }

    func submit(_ request: BGProcessingTaskRequest) throws {
        try submitClosure(request)
    }
}

@available(iOS 13, *)
final class BGProcessingTaskRequestAdapter: BackgroundProcessingRequesting {
    let request: BGProcessingTaskRequest

    init(identifier: String) {
        request = BGProcessingTaskRequest(identifier: identifier)
    }

    var requiresExternalPower: Bool {
        get { request.requiresExternalPower }
        set { request.requiresExternalPower = newValue }
    }

    var requiresNetworkConnectivity: Bool {
        get { request.requiresNetworkConnectivity }
        set { request.requiresNetworkConnectivity = newValue }
    }
}

@available(iOS 13, *)
final class BGProcessingTaskAdapter: BackgroundProcessingTasking {
    private let task: PlatformBackgroundProcessingTasking

    init(task: PlatformBackgroundProcessingTasking) {
        self.task = task
    }

    var expirationHandler: (() -> Void)? {
        get { task.expirationHandler }
        set { task.expirationHandler = newValue }
    }

    func setTaskCompleted(success: Bool) {
        task.setTaskCompleted(success: success)
    }
}

@available(iOS 13, *)
struct SystemBackgroundTaskScheduler: BackgroundTaskScheduling {
    private let scheduler: PlatformBackgroundTaskScheduling

    init(scheduler: PlatformBackgroundTaskScheduling = LivePlatformBackgroundTaskScheduler()) {
        self.scheduler = scheduler
    }

    @discardableResult
    func register(
        identifier: String,
        launchHandler: @escaping (BackgroundProcessingTasking) -> Void
    ) -> Bool {
        scheduler.register(identifier: identifier) { task in
            launchHandler(BGProcessingTaskAdapter(task: task))
        }
    }

    func makeRequest(identifier: String) -> BackgroundProcessingRequesting {
        BGProcessingTaskRequestAdapter(identifier: identifier)
    }

    func submit(_ request: BackgroundProcessingRequesting) throws {
        guard let request = request as? BGProcessingTaskRequestAdapter else {
            return
        }
        try scheduler.submit(request.request)
    }
}

@available(iOS 13, *)
final class OperationQueueAdapter: BackgroundOperationQueueing {
    private let queue = OperationQueue()

    var maxConcurrentOperationCount: Int {
        get { queue.maxConcurrentOperationCount }
        set { queue.maxConcurrentOperationCount = newValue }
    }

    func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        queue.addOperations(ops, waitUntilFinished: wait)
    }

    func cancelAllOperations() {
        queue.cancelAllOperations()
    }
}

@available(iOS 13, *)
public final class BackgroundProcessServiceiOS13: BackgroundProcessService {
    private let dataPruningOperationsManager: DataPruningOperationsManager
    private let scheduler: BackgroundTaskScheduling
    private let operationQueueFactory: () -> BackgroundOperationQueueing
    private let dataPruning = "com.ruuvi.station.BackgroundProcessServiceiOS13.dataPruning"

    public init(dataPruningOperationsManager: DataPruningOperationsManager) {
        self.dataPruningOperationsManager = dataPruningOperationsManager
        scheduler = SystemBackgroundTaskScheduler()
        operationQueueFactory = Self.makeOperationQueue
    }

    static func makeOperationQueue() -> BackgroundOperationQueueing {
        OperationQueueAdapter()
    }

    init(
        dataPruningOperationsManager: DataPruningOperationsManager,
        scheduler: BackgroundTaskScheduling,
        operationQueueFactory: @escaping () -> BackgroundOperationQueueing
    ) {
        self.dataPruningOperationsManager = dataPruningOperationsManager
        self.scheduler = scheduler
        self.operationQueueFactory = operationQueueFactory
    }

    public func register() {
        scheduler.register(identifier: dataPruning) { task in
            self.handleDataPruning(task: task)
        }
    }

    public func schedule() {
        do {
            let request = scheduler.makeRequest(identifier: dataPruning)
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = false
            try scheduler.submit(request)
        } catch {
            print(error)
        }
    }

    private func handleDataPruning(task: BackgroundProcessingTasking) {
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
        task: BackgroundProcessingTasking
    ) {
        let queue = operationQueueFactory()
        queue.maxConcurrentOperationCount = 1

        let lastOperation = operations[operations.count - 1]

        lastOperation.completionBlock = {
            task.setTaskCompleted(success: !lastOperation.isCancelled)
        }

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        queue.addOperations(operations, waitUntilFinished: false)
    }
}
