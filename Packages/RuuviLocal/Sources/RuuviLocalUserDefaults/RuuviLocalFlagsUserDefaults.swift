import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    @UserDefault("RuuviFeatureFlags.showNewCardsMenu", defaultValue: false)
    var showNewCardsMenu: Bool

#if DEBUG || ALPHA
    @UserDefault("RuuviFeatureFlags.showImprovedSensorSettingsUI", defaultValue: false)
#else
    @UserDefault("RuuviFeatureFlags.showImprovedSensorSettingsUI", defaultValue: false)
#endif
    var showImprovedSensorSettingsUI: Bool

    @UserDefault("RuuviFeatureFlags.downloadBetaFirmware", defaultValue: false)
    var downloadBetaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.downloadAlphaFirmware", defaultValue: false)
    var downloadAlphaFirmware: Bool

    @UserDefault("RuuviFeatureFlags.showVisibilitySettings", defaultValue: false)
    var showVisibilitySettings: Bool
}
