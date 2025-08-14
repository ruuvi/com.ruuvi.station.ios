import Foundation

class TimestampUpdateService {
    static let shared = TimestampUpdateService()

    private var timer: Timer?
    private var subscribers: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    private init() {}

    func addSubscriber(_ view: AnyObject & TimestampUpdateable) {
        subscribers.add(view)
        startTimerIfNeeded()
    }

    func removeSubscriber(_ view: AnyObject) {
        subscribers.remove(view)
        stopTimerIfEmpty()
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateAllSubscribers()
        }
    }

    private func stopTimerIfEmpty() {
        guard subscribers.count == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func updateAllSubscribers() {
        for subscriber in subscribers.allObjects {
            if let updateableView = subscriber as? TimestampUpdateable {
                updateableView.updateTimestampLabel()
            }
        }
    }
}

// MARK: - Protocol for Timestamp Updates
protocol TimestampUpdateable: AnyObject {
    func updateTimestampLabel()
}
