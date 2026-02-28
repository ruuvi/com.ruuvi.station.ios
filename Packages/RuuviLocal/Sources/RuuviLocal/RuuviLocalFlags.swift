import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    /// When enabled show Sensor Card UI with New Menu
    var showNewCardsMenu: Bool { get set }

    /// When enabled downloads beta version instead of stable
    var downloadBetaFirmware: Bool { get set }

    /// When enabled downloads alpha version
    var downloadAlphaFirmware: Bool { get set }

    /// When enabled, opening graph auto-starts GATT history sync
    /// for local (non-cloud) Ruuvi Air sensors.
    var autoSyncGattHistoryForRuuviAir: Bool { get set }

    /// Minimum age (in minutes) of the last datapoint before
    /// auto GATT sync starts for Ruuvi Air.
    /// `0` means always auto sync.
    var autoSyncGattHistoryForRuuviAirMinimumLastDataAgeMinutes: Int { get set }

    /// When enabled, multiple GATT history sync operations can run
    /// while navigating between sensors in graph.
    var allowConcurrentGattSyncForMultipleSensors: Bool { get set }

    /// When enabled, the marketing/communication preference toggle
    /// is shown on the My Ruuvi account screen.
    var showMarketingPreference: Bool { get set }

    /// When enabled, shows a search button on the dashboard that
    /// expands into a search bar to filter sensors by name.
    var showDashboardSensorSearch: Bool { get set }

    /// Maximum number of points used for graph downsampling.
    /// Defaults to 3000.
    var graphDownsampleMaximumPoints: Int { get set }
}
