import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showNewCardsMenu", defaultValue: false)
    var showNewCardsMenu: Bool

    @UserDefault("RuuviFeatureFlags.downloadBetaFirmware", defaultValue: false)
    var downloadBetaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.downloadAlphaFirmware", defaultValue: false)
    var downloadAlphaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.autoSyncGattHistoryForRuuviAir", defaultValue: true)
    var autoSyncGattHistoryForRuuviAir: Bool

    // Keep the existing storage key to preserve previously saved values.
    @UserDefault("RuuviFeatureFlags.autoSyncGattHistoryForRuuviAirMinimumLastDataAgeMinutes", defaultValue: 5)
    var autoSyncGattHistoryForRuuviAirMinimumLastSyncDateAgeMinutes: Int

    @UserDefault("RuuviFeatureFlags.allowConcurrentGattSyncForMultipleSensors", defaultValue: true)
    var allowConcurrentGattSyncForMultipleSensors: Bool

    @UserDefault("RuuviFeatureFlags.showMarketingPreference", defaultValue: false)
    var showMarketingPreference: Bool

    @UserDefault("RuuviFeatureFlags.showDashboardSensorSearch", defaultValue: false)
    var showDashboardSensorSearch: Bool

    @UserDefault("RuuviFeatureFlags.graphDownsampleMaximumPoints", defaultValue: 3000)
    var graphDownsampleMaximumPoints: Int

}
