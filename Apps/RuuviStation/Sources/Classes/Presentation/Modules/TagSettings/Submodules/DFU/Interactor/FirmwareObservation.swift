import Combine
import Foundation

/// One subscription owns one Bluetooth observation and its timeout.
func firmwareObservation<Output, Failure: Error>(
    delay: TimeInterval = 0,
    timeout: (TimeInterval, Failure)? = nil,
    start: @escaping (@escaping (Result<Output, Failure>) -> Void) -> (() -> Void)?
) -> AnyPublisher<Output, Failure> {
    Deferred {
        let operation = FirmwareObservation<Output, Failure>(delay: delay, timeout: timeout, start: start)
        return Future<Output, Failure> { operation.begin($0) }
            .handleEvents(receiveCancel: { operation.cancel() })
    }.eraseToAnyPublisher()
}

private final class FirmwareObservation<Output, Failure: Error> {
    private let delay: TimeInterval
    private let timeout: (TimeInterval, Failure)?
    private let start: (@escaping (Result<Output, Failure>) -> Void) -> (() -> Void)?
    private var promise: ((Result<Output, Failure>) -> Void)?
    private var startWork: DispatchWorkItem?
    private var timeoutWork: DispatchWorkItem?
    private var cancelObservation: (() -> Void)?
    private var finished = false

    init(
        delay: TimeInterval, timeout: (TimeInterval, Failure)?,
        start: @escaping (@escaping (Result<Output, Failure>) -> Void) -> (() -> Void)?
    ) {
        self.delay = delay
        self.timeout = timeout
        self.start = start
    }

    func begin(_ promise: @escaping (Result<Output, Failure>) -> Void) {
        DispatchQueue.main.async { [self] in
            guard !finished else { return }
            self.promise = promise
            let work = DispatchWorkItem { [weak self] in self?.startObservation() }
            startWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay), execute: work)
        }
    }

    private func startObservation() {
        guard !finished else { return }
        startWork = nil
        cancelObservation = start { [weak self] result in
            DispatchQueue.main.async { self?.finish(result) }
        }
        if let (duration, error) = timeout {
            let work = DispatchWorkItem { [weak self] in self?.finish(.failure(error)) }
            timeoutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, duration), execute: work)
        }
    }

    func cancel() {
        DispatchQueue.main.async { [self] in finish(nil) }
    }

    private func finish(_ result: Result<Output, Failure>?) {
        guard !finished else { return }
        finished = true
        startWork?.cancel(); startWork = nil
        timeoutWork?.cancel(); timeoutWork = nil
        let cancellation = cancelObservation
        cancelObservation = nil
        let completion = promise
        promise = nil
        cancellation?()
        if let result { completion?(result) }
    }
}
