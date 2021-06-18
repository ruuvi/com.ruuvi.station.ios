import Foundation

open class RuuviDaemonWorker: NSObject {
    public var thread: Thread!
    private var block: (() -> Void)!

    override public init() {}

    @objc internal func runBlock() {
        autoreleasepool {
            block()
        }
    }

    open func start(_ block: @escaping () -> Void) {
        self.block = block

        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]

        thread = Thread { [weak self] in
            while self != nil && !self!.thread.isCancelled {
                RunLoop.current.run(
                    mode: RunLoop.Mode.default,
                    before: Date.distantFuture)
            }
            Thread.exit()
        }
        thread.name = "\(threadName)-\(UUID().uuidString)"
        thread.start()

        perform(#selector(runBlock),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    public func stopWork() {
        perform(#selector(stopThread),
                on: thread,
                with: nil,
                waitUntilDone: false,
                modes: [RunLoop.Mode.default.rawValue])
    }

    @objc func stopThread() {
        Thread.exit()
    }

}
