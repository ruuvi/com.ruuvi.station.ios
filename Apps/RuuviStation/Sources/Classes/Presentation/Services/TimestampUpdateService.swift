import Foundation

class TimestampUpdateService {
    static let shared = TimestampUpdateService()

    private var timer: Timer?
    private var subscribers: NSHashTable<AnyObject> = NSHashTable.weakObjects()

    private init() {}

    func addSubscriber(_ cell: AnyObject & TimestampUpdateable) {
        subscribers.add(cell)
        startTimerIfNeeded()
    }

    func removeSubscriber(_ cell: AnyObject) {
        subscribers.remove(cell)
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
            if let updateableCell = subscriber as? TimestampUpdateable {
                updateableCell.updateTimestampLabel()
            }
        }
    }
}

// MARK: - Protocol for Timestamp Updates
protocol TimestampUpdateable: AnyObject {
    func updateTimestampLabel()
}
