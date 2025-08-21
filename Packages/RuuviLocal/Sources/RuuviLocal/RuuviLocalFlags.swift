import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    /// When enabled show redesigned Dashboard
    var showRedesignedDashboardUI: Bool { get set }

    /// When enabled show redesigned Sensor Card UI without New Menu
    var showRedesignedCardsUIWithoutNewMenu: Bool { get set }

    /// When enabled show redesigned Sensor Card UI with New Menu
    var showRedesignedCardsUIWithNewMenu: Bool { get set }

    /// When enabled downloads beta version instead of stable
    var downloadBetaFirmware: Bool { get set }

    /// When enabled downloads alpha version
    var downloadAlphaFirmware: Bool { get set }
}
