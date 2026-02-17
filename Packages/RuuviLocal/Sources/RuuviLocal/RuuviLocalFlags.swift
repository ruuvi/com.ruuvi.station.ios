import Foundation

public protocol RuuviLocalFlags {
    // MARK: Legacy flags
    // TODO: Move legacy feature flags here
    // MARK: End Legacy flags

    /// When enabled show Sensor Card UI with New Menu
    var showNewCardsMenu: Bool { get set }

    /// When enabled downloads beta version instead of stable
    var downloadBetaFirmware: Bool { get set }

    /// When enabled downloads alpha version
    var downloadAlphaFirmware: Bool { get set }

    /// When enabled, opening graph auto-starts GATT history sync
    /// for local (non-cloud) Ruuvi Air sensors.
    var autoSyncGattHistoryForRuuviAir: Bool { get set }

}
