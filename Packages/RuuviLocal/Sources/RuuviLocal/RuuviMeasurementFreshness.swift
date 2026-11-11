import Foundation

/// Shared by the dashboard, sensor card, and developer timeout editor.
public enum RuuviMeasurementFreshness {
    public static let defaultTimeoutSeconds = 60 * 60
    public static let allowedTimeoutSeconds = 1...Int(Int32.max)

    public static func normalizedTimeout(_ seconds: Int) -> Int {
        min(allowedTimeoutSeconds.upperBound, max(allowedTimeoutSeconds.lowerBound, seconds))
    }

    public static func isStale(
        lastUpdated: Date?,
        timeoutSeconds: Int = defaultTimeoutSeconds,
        now: Date = Date()
    ) -> Bool {
        // A sensor without measurements already has a separate "No data" state.
        guard let lastUpdated else { return false }
        return now.timeIntervalSince(lastUpdated) >= TimeInterval(normalizedTimeout(timeoutSeconds))
    }
}
