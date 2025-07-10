import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    /// When enabled show redesigned Dashboard
    var showRedesignedDashboardUI: Bool { get set }
}
