import RuuviLocalization
import UIKit

struct GlobalHelpers {
    static func isDeviceTablet() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static func isDeviceLandscape() -> Bool {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape && !orientation.isFlat
    }

    static func getBool(from value: Bool?) -> Bool {
        if let value {
            value
        } else {
            false
        }
    }

    static func ruuviTagDefaultName(from macId: String?, luid: String?) -> String {
        // identifier
        if let mac = macId {
            RuuviLocalization.DiscoverTable.RuuviDevice.prefix
                + " " + mac.replacingOccurrences(of: ":", with: "").suffix(4)
        } else {
            RuuviLocalization.DiscoverTable.RuuviDevice.prefix
                + " " + (luid?.prefix(4) ?? "")
        }
    }

    func formattedString(from double: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: double)) ?? "0"
    }
}
