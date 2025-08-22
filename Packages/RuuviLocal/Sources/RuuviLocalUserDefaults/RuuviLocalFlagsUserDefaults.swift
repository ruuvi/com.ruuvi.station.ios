import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

#if DEBUG || ALPHA
    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: true)
#else
    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: false)
#endif
    var showRedesignedDashboardUI: Bool

#if DEBUG || ALPHA
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithoutNewMenu", defaultValue: true)
#else
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithoutNewMenu", defaultValue: false)
#endif
    var showRedesignedCardsUIWithoutNewMenu: Bool

    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithNewMenu", defaultValue: false)
    var showRedesignedCardsUIWithNewMenu: Bool

    @UserDefault("RuuviFeatureFlags.downloadBetaFirmware", defaultValue: false)
    var downloadBetaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.downloadAlphaFirmware", defaultValue: false)
    var downloadAlphaFirmware: Bool
}
