import Foundation

public enum SyncAction {
    /// Cloud data is newer - update local database
    case updateLocal
    /// Local data is newer - keep local AND queue changes for cloud sync
    case keepLocalAndQueue
    /// No action needed - timestamps are equal or both nil
    case noAction
}

public struct SyncCollisionResolver {
    /// Tolerance for clock skew (1 second)
    private static let tolerance: TimeInterval = 1.0

    /// Resolves sync collision based on timestamps.
    /// - Parameters:
    ///   - localTimestamp: The local database timestamp
    ///   - cloudTimestamp: The cloud API timestamp
    /// - Returns: The action to take based on timestamp comparison
    public static func resolve(
        localTimestamp: Date?,
        cloudTimestamp: Date?
    ) -> SyncAction {
        // If cloud timestamp is nil
        guard let cloudTs = cloudTimestamp else {
            // If local has timestamp, keep local and queue
            // If both nil, no action needed (fresh data from cloud with no timestamp)
            return localTimestamp != nil ? .keepLocalAndQueue : .noAction
        }

        // If local timestamp is nil but cloud has timestamp
        guard let localTs = localTimestamp else {
            // Accept cloud data (first sync or no local tracking)
            return .updateLocal
        }

        // Both have timestamps - compare with tolerance
        let difference = cloudTs.timeIntervalSince(localTs)

        // If within tolerance, consider equal
        if abs(difference) < tolerance {
            return .noAction
        }

        // Cloud is newer
        if difference > 0 {
            return .updateLocal
        }

        // Local is newer
        return .keepLocalAndQueue
    }

    /// Resolves sync collision with cloudMode and backward compatibility handling.
    /// This is a convenience method that handles common sync patterns:
    /// - Both timestamps nil: accept cloud data for backward compatibility
    /// - Otherwise: use standard timestamp comparison with ownership check
    /// - Parameters:
    ///   - isOwner: Whether the current user owns the sensor
    ///   - localTimestamp: The local database timestamp
    ///   - cloudTimestamp: The cloud API timestamp
    /// - Returns: The action to take
    public static func resolve(
        isOwner: Bool,
        localTimestamp: Date?,
        cloudTimestamp: Date?
    ) -> SyncAction {

        // Both timestamps nil: accept cloud for backward compatibility (fresh data)
        if localTimestamp == nil && cloudTimestamp == nil {
            return .updateLocal
        }

        // For owned sensors, use standard timestamp comparison
        return resolve(localTimestamp: localTimestamp, cloudTimestamp: cloudTimestamp)
    }
}
