import CoreFoundation
import Foundation

open class RuuviDaemonWorker: NSObject {
    private let lifecycleLock = NSRecursiveLock()
    private var workerThread: Thread?
    private var stoppingThreads = Set<ObjectIdentifier>()
    public var thread: Thread! {
        get {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            return workerThread
        }
        set {
            lifecycleLock.lock()
            defer { lifecycleLock.unlock() }
            workerThread = newValue
        }
    }
    private let workerID = UUID().uuidString
    private static let workerIDKey = "RuuviDaemonWorker.workerID"
    private static let runLoopStopper = RunLoopStopper()

    // A separate selector target lets teardown wake the thread without retaining a deallocating worker.
    private final class RunLoopStopper: NSObject {
        @objc func stop() {
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }

    private final class Work: NSObject {
        let block: () -> Void

        init(_ block: @escaping () -> Void) {
            self.block = block
        }
    }

    override public init() {}

    deinit {
        guard let workerThread, !workerThread.isFinished else { return }
        workerThread.cancel()
        if workerThread == Thread.current {
            CFRunLoopStop(CFRunLoopGetCurrent())
        } else {
            Self.runLoopStopper.perform(
                #selector(RunLoopStopper.stop),
                on: workerThread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue]
            )
        }
    }

    @objc private func runBlock(_ work: Work) {
        autoreleasepool {
            work.block()
        }
    }

    open func start(_ block: @escaping () -> Void) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        // Wake and stop the previous run loop after any cleanup already queued on it.
        if let previous = thread {
            requestStop(on: previous)
        }
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        let workerID = workerID
        let workerThread = Thread { [weak self] in
            Thread.current.threadDictionary[Self.workerIDKey] = workerID
            // Keep the run loop asleep when it has no pending work.
            let port = Port()
            RunLoop.current.add(port, forMode: .default)
            defer { port.invalidate() }
            while self != nil, !Thread.current.isCancelled {
                RunLoop.current.run(
                    mode: RunLoop.Mode.default,
                    before: Date.distantFuture
                )
            }
        }
        workerThread.name = "\(threadName)-\(UUID().uuidString)"
        thread = workerThread
        workerThread.start()

        perform(
            #selector(runBlock(_:)),
            on: workerThread,
            with: Work(block),
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    public func stopWork() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        // A previous session may still be stopping after `thread` was replaced.
        let current = Thread.current
        let target = current.threadDictionary[Self.workerIDKey] as? String == workerID ? current : thread
        guard let target else { return }
        requestStop(on: target)
    }

    private func requestStop(on target: Thread) {
        guard !target.isCancelled, !target.isFinished,
              stoppingThreads.insert(ObjectIdentifier(target)).inserted else { return }
        if target == Thread.current {
            stopThread()
            return
        }
        perform(
            #selector(stopThread),
            on: target,
            with: nil,
            waitUntilDone: false,
            modes: [RunLoop.Mode.default.rawValue]
        )
    }

    @objc func stopThread() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        Thread.current.cancel()
        CFRunLoopStop(CFRunLoopGetCurrent())
        stoppingThreads.remove(ObjectIdentifier(Thread.current))
    }
}
