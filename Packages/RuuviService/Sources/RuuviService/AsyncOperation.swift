import Foundation

open class AsyncOperation: Operation {
    public enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            "is" + rawValue.capitalized
        }
    }

    private let stateLock = NSRecursiveLock()
    private var storedState = State.ready

    open var state: State {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return storedState
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            let oldValue = storedState
            guard oldValue != newValue else { return }
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: oldValue.keyPath)
            storedState = newValue
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: newValue.keyPath)
        }
    }

    private func beginExecution() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard state == .ready else { return false }
        guard !isCancelled else {
            state = .finished
            return false
        }
        state = .executing
        // KVO observers can cancel reentrantly during the state transition.
        guard !isCancelled else {
            state = .finished
            return false
        }
        return true
    }
}

extension AsyncOperation {
    override open var isReady: Bool {
        super.isReady && state == .ready
    }

    override open var isExecuting: Bool {
        state == .executing
    }

    override open var isFinished: Bool {
        state == .finished
    }

    override open var isAsynchronous: Bool {
        true
    }

    override open func start() {
        guard beginExecution() else { return }
        // Do not hold the state lock while calling subclass code.
        main()
    }

    override open func cancel() {
        stateLock.lock()
        defer { stateLock.unlock() }
        // Set the cancellation flag before finishing can invoke completionBlock.
        super.cancel()
        if isExecuting {
            state = .finished
        }
    }
}
