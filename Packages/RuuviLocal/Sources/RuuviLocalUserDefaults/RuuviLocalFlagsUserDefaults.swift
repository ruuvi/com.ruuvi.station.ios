import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showRedesignedDashboardUI", defaultValue: true)
    var showRedesignedDashboardUI: Bool

    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithoutNewMenu", defaultValue: true)
    var showRedesignedCardsUIWithoutNewMenu: Bool

    @UserDefault("RuuviFeatureFlags.showRedesignedCardsUIWithNewMenu", defaultValue: false)
    var showRedesignedCardsUIWithNewMenu: Bool

    @UserDefault("RuuviFeatureFlags.downloadBetaFirmware", defaultValue: false)
    var downloadBetaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.downloadAlphaFirmware", defaultValue: false)
    var downloadAlphaFirmware: Bool
}
