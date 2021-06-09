import Foundation
import iOSDFULibrary

struct RuuviDfu {
    static let shared = RuuviDfu()

    private let scanner = DfuScanner()
    private let flasher = DfuFlasher()

    @discardableResult
    func scan<T: AnyObject>(_ observer: T,
                            closure: @escaping (T, DfuDevice) -> Void) -> RUObservationToken {
        return scanner.scan(observer, closure: closure)
    }

    @discardableResult
    func lost<T: AnyObject>(_ observer: T, closure: @escaping (T, DfuDevice) -> Void) -> RUObservationToken {
        return scanner.lost(observer, closure: closure)
    }

    func firmwareFromUrl(url: URL) -> DFUFirmware? {
        return DFUFirmware(urlToZipFile: url, type: .softdeviceBootloaderApplication)
    }

    func flashFirmware(device: DfuDevice,
                       with firmware: DFUFirmware,
                       output: DfuFlasherOutputProtocol) {
        flasher.flashFirmware(device: device, with: firmware, output: output)
    }

    func stopFlashFirmware(device: DfuDevice) -> Bool {
        return flasher.stopFlashFirmware(device: device)
    }
}

extension DFUFirmware {
    var log: DfuLog {
        let str = "\("DfuFlash.Firmware.FileName.text".localized()): \(fileName ?? "")"
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.Parts.text".localized()): \(parts)")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.Size.text".localized()): \(size.application / 1024) KB")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.SoftDeviceSize.text".localized()): \(size.softdevice / 1024) KB")
            .appending("\r\n")
            .appending("\("DfuFlash.Firmware.BootloaderSize.text".localized()): \(size.bootloader) byte")
        return DfuLog(message: str, time: Date())
    }
}
