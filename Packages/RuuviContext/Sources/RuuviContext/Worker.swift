import Foundation

/// Executes submitted work serially, in submission order, off the main thread.
/// Submitted work completes even if the worker's owner is released.
public class Worker {
    private let queue = DispatchQueue(label: "com.ruuvi.station.worker", qos: .default)

    public init() {}

    public func enqueue(_ block: @escaping () -> Void) {
        queue.async(execute: DispatchWorkItem(block: block))
    }
}
