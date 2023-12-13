import Foundation
import RuuviDFU
import RuuviLocalization
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif

extension DFUFirmware {
    var log: DFULog {
        let str = "\(RuuviLocalization.DfuFlash.Firmware.FileName.text): \(fileName ?? "")"
            .appending("\r\n")
            .appending("\(RuuviLocalization.DfuFlash.Firmware.Parts.text): \(parts)")
            .appending("\r\n")
            .appending("\(RuuviLocalization.DfuFlash.Firmware.Size.text): \(size.application / 1024) KB")
            .appending("\r\n")
            .appending("\(RuuviLocalization.DfuFlash.Firmware.SoftDeviceSize.text): \(size.softdevice / 1024) KB")
            .appending("\r\n")
            .appending("\(RuuviLocalization.DfuFlash.Firmware.BootloaderSize.text): \(size.bootloader) byte")
        return DFULog(message: str, time: Date())
    }
}
