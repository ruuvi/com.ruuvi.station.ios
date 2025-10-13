import RuuviLocalization
import UIKit
import RuuviOntology

struct Helpers {

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

    static func ruuviAirDefaultName(
        from macId: String
    ) -> String {
        return RuuviLocalization.ruuviAir + " " +
            macId.replacingOccurrences(of: ":", with: "").suffix(4)
    }
}
