import Foundation

struct DispatchQueueManager {
    // Dedicated queues for different operations
    static let sensorData = DispatchQueue(label: "com.ruuvi.sensorData", qos: .userInitiated)
    static let backgroundImages = DispatchQueue(label: "com.ruuvi.backgroundImages", qos: .utility)
    static let alerts = DispatchQueue(label: "com.ruuvi.alerts", qos: .userInitiated)
    static let connections = DispatchQueue(label: "com.ruuvi.connections", qos: .userInitiated)
    static let cloudSync = DispatchQueue(label: "com.ruuvi.cloudSync", qos: .utility)
    
    // Helper for main thread updates
    static func updateUI(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
    
    // Helper for background work with main thread callback
    static func performBackground<T>(
        on queue: DispatchQueue = .global(qos: .userInitiated),
        work: @escaping () -> T,
        completion: @escaping (T) -> Void
    ) {
        queue.async {
            let result = work()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
