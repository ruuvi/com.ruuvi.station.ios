import Foundation

extension Bundle {
    var isRuuvi: Bool {
        return bundleIdentifier?.compare("com.ruuvi.station") == .orderedSame
    }
}
