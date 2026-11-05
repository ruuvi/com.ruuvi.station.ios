#if SWIFT_PACKAGE
    import RuuviDFU
#endif
import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif

final class DFUNordicTransport: NSObject, DFULegacyFlashing, DFUServiceDelegate, DFUProgressDelegate, LoggerDelegate {
    private let initiator: DFUServiceInitiator
    private var controller: DFUServiceController?
    var event: ((FlashResponse) -> Void)?
    var completion: ((Result<Void, Error>) -> Void)?

    init(queue: DispatchQueue) {
        initiator = DFUServiceInitiator(
            queue: queue, delegateQueue: queue, progressQueue: queue, loggerQueue: queue)
        super.init()
    }

    func start(
        uuid: UUID, firmware: DFUFirmware, event: @escaping (FlashResponse) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        self.event = event
        self.completion = completion
        initiator.delegate = self
        initiator.progressDelegate = self
        initiator.logger = self
        controller = initiator.with(firmware: firmware).start(targetWithIdentifier: uuid)
        return controller != nil
    }

    func cancel() -> Bool { controller?.abort() ?? false }
    func dfuStateDidChange(to state: DFUState) {
        if state == .completed { finish(.success(())) }
        if state == .aborted { finish(.failure(RuuviDfuError(description: "Upload cancelled"))) }
    }
    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        finish(.failure(RuuviDfuError(description: message)))
    }
    func dfuProgressDidChange(
        for part: Int, outOf totalParts: Int, to progress: Int,
        currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double
    ) {
        guard totalParts > 0, part > 0, part <= totalParts else { return }
        let completed = Double(part - 1) + Double(min(100, max(0, progress))) / 100
        event?(.progress(completed / Double(totalParts)))
    }
    func logWith(_ level: LogLevel, message: String) {
        event?(.log(DFULog(message: message, time: Date())))
    }
    private func finish(_ result: Result<Void, Error>) {
        let callback = completion
        completion = nil
        event = nil
        controller = nil
        callback?(result)
    }
}

final class DFUMcuTransport: DFUFileTransport {
    private let transport: McuMgrBleTransport
    private let defaultManager: DefaultManager
    private var fileManager: FileSystemManager?
    private var delegate: DFUUploadDelegate?

    init(device: DFUDevice) throws {
        guard let peripheral = device.peripheral as? CBPeripheral else {
            throw RuuviDfuError(description: "Bluetooth peripheral unavailable")
        }
        transport = McuMgrBleTransport(peripheral)
        defaultManager = DefaultManager(transport: transport)
    }

    func upload(
        path: String, data: Data, progress: @escaping (Int) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let delegate = DFUUploadDelegate(progress: progress, completion: completion)
        let manager = FileSystemManager(transport: transport)
        self.delegate = delegate
        fileManager = manager
        return manager.upload(name: path, data: data, delegate: delegate)
    }

    func reset(completion: @escaping (Error?) -> Void) {
        defaultManager.reset { response, error in
            if let error {
                completion(error)
            } else if let response {
                completion(response.getError())
            } else {
                completion(RuuviDfuError(description: "Missing device reset response"))
            }
        }
    }

    func cancel() { fileManager?.cancelTransfer() }
}

/// Each file gets a separate delegate, so late callbacks cannot finish a later file.
final class DFUUploadDelegate: FileUploadDelegate {
    private let lock = NSRecursiveLock()
    private var progress: ((Int) -> Void)?
    private var completion: ((Result<Void, Error>) -> Void)?
    init(progress: @escaping (Int) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        self.progress = progress
        self.completion = completion
    }
    func uploadProgressDidChange(bytesSent: Int, fileSize: Int, timestamp: Date) {
        lock.lock()
        defer { lock.unlock() }
        progress?(bytesSent)
    }
    func uploadDidFinish() { finish(.success(())) }
    func uploadDidFail(with error: Error) { finish(.failure(error)) }
    func uploadDidCancel() { finish(.failure(RuuviDfuError(description: "Upload cancelled"))) }
    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let callback = completion
        completion = nil
        progress = nil
        lock.unlock()
        callback?(result)
    }
}
