import Foundation

// Shared timestamp rules for foreground advertisement-triggered history downloads.
enum AutomaticGattSyncPolicy {
    static func isEligible(
        now: Date,
        lastSync: Date?,
        lastAttempt: Date?,
        cooldownMinutes: Int
    ) -> Bool {
        guard cooldownMinutes > 0 else { return true }
        guard let latest = [lastSync, lastAttempt].compactMap({ $0 }).max() else { return true }
        return now.timeIntervalSince(latest) >= TimeInterval(cooldownMinutes) * 60
    }

    static func syncFrom(now: Date, lastSync: Date?, historyHours: Int) -> Date {
        let earliest = now.addingTimeInterval(-TimeInterval(max(0, historyHours)) * 60 * 60)
        return max(lastSync ?? earliest, earliest)
    }
}
