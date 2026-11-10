import Foundation

@MainActor
class TimestampUpdateService {
    static let shared = TimestampUpdateService()

    private let freshnessServices = NSHashTable<MeasurementFreshnessService>.weakObjects()
    private var timer: Timer?
    private var subscribers: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    private init() {}

    func addFreshnessService(_ service: MeasurementFreshnessService) {
        freshnessServices.add(service)
    }

    func addSubscriber(_ view: AnyObject & TimestampUpdateable) {
        subscribers.add(view)
        startTimerIfNeeded()
    }

    func removeSubscriber(_ view: AnyObject) {
        subscribers.remove(view)
        stopTimerIfEmpty()
    }

    func refresh() {
        updateAllSubscribers()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateAllSubscribers() }
        }
    }

    private func stopTimerIfEmpty() {
        guard subscribers.count == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func updateAllSubscribers() {
        freshnessServices.allObjects.forEach { $0.refresh() }
        for subscriber in subscribers.allObjects {
            if let updateableView = subscriber as? TimestampUpdateable {
                updateableView.updateTimestampLabel()
            }
        }
        stopTimerIfEmpty()
    }
}

// MARK: - Protocol for Timestamp Updates
@MainActor
protocol TimestampUpdateable: AnyObject {
    func updateTimestampLabel()
}
