import Foundation

final class RuuviLocalFlagsUserDefaults: RuuviLocalFlags {

    // MARK: Legacy flags
    // These flags were initially part of SettingsUserDefaults. But, now moved to
    // RuuviLocalFlagsUserDefaults to separate them from other settings.
    // But, we can not change the UserDefaults key for these flags because we need to
    // keep the existing values. So, we are keeping the same key for these flags.
    @UserDefault("SettingsUserDefaults.experimentalFeaturesEnabled", defaultValue: false)
    var experimentalFeaturesEnabled: Bool

    @UserDefault("SettingsUserDefaults.showSwitchStatusLabel", defaultValue: true)
    var showSwitchStatusLabel: Bool

    @UserDefault("SettingsUserDefaults.showAlertsRangeInGraph", defaultValue: false)
    var showAlertsRangeInGraph: Bool

    @UserDefault("SettingsUserDefaults.useNewGraphRendering", defaultValue: false)
    var useNewGraphRendering: Bool

    @UserDefault("SettingsUserDefaults.historySyncLegacy", defaultValue: false)
    var historySyncLegacy: Bool

    @UserDefault("SettingsUserDefaults.historySyncOnDashboard", defaultValue: false)
    var historySyncOnDashboard: Bool

    @UserDefault("SettingsUserDefaults.historySyncForEachSensor", defaultValue: true)
    var historySyncForEachSensor: Bool

    @UserDefault("SettingsUserDefaults.includeDataSourceInHistoryExport", defaultValue: false)
    var includeDataSourceInHistoryExport: Bool
    // MARK: End Legacy flags
}
