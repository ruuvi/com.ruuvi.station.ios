import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.useImprovedDashboard", defaultValue: true)
    var useImprovedDashboard: Bool

    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: false)
    var showRedesignedDashboardUI: Bool
}
