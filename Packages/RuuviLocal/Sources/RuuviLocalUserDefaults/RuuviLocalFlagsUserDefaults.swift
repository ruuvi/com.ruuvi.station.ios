import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: false)
    var showRedesignedDashboardUI: Bool

#if DEBUG || ALPHA
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithNewMenu", defaultValue: true)
#else
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithNewMenu", defaultValue: false)
#endif
    var showRedesignedCardsUIWithNewMenu: Bool
}
