import Combine
import Foundation
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif

public struct RuuviDFUImpl: RuuviDFU {
    public static let shared = RuuviDFUImpl()

    private let scanner = DfuScanner()
    private let flasher = DfuFlasher()

    @discardableResult
    public func scan<T: AnyObject>(
        _ observer: T,
        includeScanServices: Bool,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        scanner.setIncludeScanServices(includeScanServices)
        return scanner.scan(observer, closure: closure)
    }

    @discardableResult
    public func lost<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken {
        scanner.lost(observer, closure: closure)
    }

    public func firmwareFromUrl(url: URL) -> DFUFirmware? {
        try? DFUFirmware(urlToZipFile: url, type: .softdeviceBootloaderApplication)
    }

    public func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        flasher.flashFirmware(uuid: uuid, with: firmware)
    }

    public func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURL: URL
    ) -> AnyPublisher<FlashResponse, any Error> {
        flasher.flashFirmware(dfuDevice: dfuDevice, with: firmwareURL)
    }

    public func stopFlashFirmware(device: DFUDevice) -> Bool {
        flasher.stopFlashFirmware(device: device)
    }
}
