import Foundation
import Combine
#if canImport(NordicDFU)
import NordicDFU
#endif
#if canImport(iOSDFULibrary)
import iOSDFULibrary
#endif

public enum FlashResponse {
    case done
    case progress(Double)
    case log(DFULog)
}

public protocol RuuviDFU {
    @discardableResult
    func scan<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken
    func lost<T: AnyObject>(
        _ observer: T,
        closure: @escaping (T, DFUDevice) -> Void
    ) -> RuuviDFUToken
    func firmwareFromUrl(url: URL) -> DFUFirmware?
    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error>

    func stopFlashFirmware(device: DFUDevice) -> Bool
}

public protocol DfuFlasherOutputProtocol: AnyObject {
    func ruuviDfuDidUpdateProgress(percentage: Float)
    func ruuviDfuDidUpdateLog(log: DFULog)
    func ruuviDfuDidFinish()
    func ruuviDfuError(error: Error)
}

public final class RuuviDFUToken {
    private let cancellationClosure: () -> Void

    public init(cancellationClosure: @escaping () -> Void) {
        self.cancellationClosure = cancellationClosure
    }

    public func invalidate() {
        cancellationClosure()
    }
}
