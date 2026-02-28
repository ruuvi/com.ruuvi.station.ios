import Foundation

class AsyncOperation: Operation {
    enum State: String {
        case ready, executing, finished

        fileprivate var keyPath: String {
            "is" + rawValue.capitalized
        }
    }

    var state = State.ready {
        willSet {
            willChangeValue(forKey: newValue.keyPath)
            willChangeValue(forKey: state.keyPath)
        }
        didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: state.keyPath)
        }
    }
}

extension AsyncOperation {
    override var isReady: Bool {
        super.isReady && state == .ready
    }

    override var isExecuting: Bool {
        state == .executing
    }

    override var isFinished: Bool {
        state == .finished
    }

    override var isAsynchronous: Bool {
        true
    }

    override func start() {
        if isCancelled {
            state = .finished
            return
        }
        // Mark as executing before `main()` to avoid finishing-state races
        // when async APIs can invoke callbacks immediately.
        state = .executing
        main()
    }

    override func cancel() {
        state = .finished
    }
}
