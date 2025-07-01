import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    /// When enabled show the improved layout; no visual changes but
    /// uses new data structure and layout code.
    var useImprovedDashboard: Bool { get set }

    /// When enabled show redesigned Dashboard
    var showRedesignedDashboardUI: Bool { get set }
}
