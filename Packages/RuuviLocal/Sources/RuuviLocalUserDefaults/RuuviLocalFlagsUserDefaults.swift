import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: false)
    var showRedesignedDashboardUI: Bool
}
