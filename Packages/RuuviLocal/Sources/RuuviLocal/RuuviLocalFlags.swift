import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    var experimentalFeaturesEnabled: Bool { get set }
    var showSwitchStatusLabel: Bool { get set }
    var showAlertsRangeInGraph: Bool { get set }
    var useNewGraphRendering: Bool { get set }

    /// Syncs full history for all sensoers after code verification
    /// on sign in, before presenting dashboard. Heavy after sign in
    /// specially if the connection is poor.
    var historySyncLegacy: Bool { get set }
    /// Syncs full history for all sensors after sign in is completed
    /// and user lands on dashboard. Heavy and can cause lag on dashboard.
    var historySyncOnDashboard: Bool { get set }
    /// Syncs full history for each sensor when associated charts
    /// is presented. Much efficient.
    var historySyncForEachSensor: Bool { get set }
    var includeDataSourceInHistoryExport: Bool { get set }
    // MARK: End Legacy flags

    /// When enabled new and improved full sensor card view is shown
    var showNewFullSensorCardView: Bool { get set }

    /// When enabled new tab style menu is shown on sensor card view
    var showNewMenuStyleOnSensorCardView: Bool { get set }
}
