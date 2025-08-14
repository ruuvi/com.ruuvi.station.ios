import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: false)
    var showRedesignedDashboardUI: Bool

#if DEBUG || ALPHA
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithoutNewMenu", defaultValue: true)
#else
    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithoutNewMenu", defaultValue: false)
#endif
    var showRedesignedCardsUIWithoutNewMenu: Bool

    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithNewMenu", defaultValue: false)
    var showRedesignedCardsUIWithNewMenu: Bool
}
