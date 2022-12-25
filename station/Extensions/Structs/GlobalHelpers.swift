import UIKit

struct GlobalHelpers {
    static func isDeviceTablet() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }

    static func isDeviceLandscape() -> Bool {
        let orientation = UIDevice.current.orientation
        return orientation.isLandscape && !orientation.isFlat
    }

    static func getBool(from value: Bool?) -> Bool {
        if let value = value {
            return value
        } else {
            return false
        }
    }
}
