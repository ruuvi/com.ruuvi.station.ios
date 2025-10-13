import RuuviLocalization
import UIKit
import RuuviOntology

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

    static func ruuviDeviceDefaultName(
        from macId: String?,
        luid: String?,
        dataFormat: Int?
    ) -> String {
        var deviceName = RuuviLocalization.ruuviTag
        if let dataFormat {
            let firmwareVersion = RuuviDataFormat.dataFormat(
                from: dataFormat
            )
            if firmwareVersion == .e1 || firmwareVersion == .v6 {
                deviceName = RuuviLocalization.ruuviAir
            }
        }

        // identifier
        if let mac = macId {
            return deviceName + " " + mac.replacingOccurrences(of: ":", with: "").suffix(4)
        } else {
            return deviceName + " " + (luid?.prefix(4) ?? "")
        }
    }

    func formattedString(
        from double: Double,
        minPlace: Int = 0,
        toPlace: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minPlace
        formatter.maximumFractionDigits = toPlace
        return formatter.string(from: NSNumber(value: double)) ?? "0"
    }
}
