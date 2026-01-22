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
    /// Tolerance for clock skew (2 seconds)
    private static let tolerance: TimeInterval = 2.0

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

    /// Resolves sync collision for shared sensors (non-owners).
    /// For shared sensors, always accept cloud data since the owner controls it.
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
        // For shared sensors (not owner), always accept cloud data
        if !isOwner {
            return .updateLocal
        }

        // For owned sensors, use standard timestamp comparison
        return resolve(localTimestamp: localTimestamp, cloudTimestamp: cloudTimestamp)
    }

    /// Resolves sync collision with cloudMode and backward compatibility handling.
    /// This is a convenience method that handles common sync patterns:
    /// - Cloud mode enabled: always accept cloud data
    /// - Both timestamps nil: accept cloud data for backward compatibility
    /// - Otherwise: use standard timestamp comparison with ownership check
    /// - Parameters:
    ///   - cloudModeEnabled: Whether cloud mode is enabled (always accept cloud)
    ///   - isOwner: Whether the current user owns the sensor
    ///   - localTimestamp: The local database timestamp
    ///   - cloudTimestamp: The cloud API timestamp
    /// - Returns: The action to take
    public static func resolve(
        cloudModeEnabled: Bool,
        isOwner: Bool,
        localTimestamp: Date?,
        cloudTimestamp: Date?
    ) -> SyncAction {
        // Cloud mode: always accept cloud data
        if cloudModeEnabled {
            return .updateLocal
        }

        // Both timestamps nil: accept cloud for backward compatibility (fresh data)
        if localTimestamp == nil && cloudTimestamp == nil {
            return .updateLocal
        }

        // Use standard resolution with ownership check
        return resolve(isOwner: isOwner, localTimestamp: localTimestamp, cloudTimestamp: cloudTimestamp)
    }
}
