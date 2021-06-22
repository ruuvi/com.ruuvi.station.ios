import Foundation
import RuuviDFU
#if canImport(NordicDFU)
import NordicDFU
#endif
#if canImport(iOSDFULibrary)
import iOSDFULibrary
#endif

extension DFUFirmware {
    var log: DFULog {
        let str = "\("DfuFlash.Firmware.FileName.text".localized()): \(fileName ?? "")"
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.Parts.text".localized()): \(parts)")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.Size.text".localized()): \(size.application / 1024) KB")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.SoftDeviceSize.text".localized()): \(size.softdevice / 1024) KB")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.BootloaderSize.text".localized()): \(size.bootloader) byte")
        return DFULog(message: str, time: Date())
    }
}
