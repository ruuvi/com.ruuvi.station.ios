import Combine
import Foundation
import iOSMcuManagerLibrary
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif

class DfuFlasher: NSObject {
    private let queue = DispatchQueue(label: "DfuFlasher", qos: .userInteractive)
    private var dfuServiceInitiator: DFUServiceInitiator
    private var firmware: DFUFirmware?
    private var partsCompleted: Int = 0
    private var currentFirmwarePartsCompleted: Int = 0
    private var dfuServiceController: DFUServiceController?
    private var subject: PassthroughSubject<FlashResponse, Error>?

    // MCUManager properties
    private var fsManager: FileSystemManager?
    private var defaultManager: DefaultManager?
    private var fileData: Data?
    private var totalFileSize: Int = 0
    private var uploadStartTime: Date?

    private struct FilesController {
        static let partitionKey = "partition_key"
        static let defaultPartition = "/lfs1"
    }

    private var partition: String {
        return UserDefaults.standard
            .string(forKey: FilesController.partitionKey)
            ?? FilesController.defaultPartition
    }

    override init() {
        dfuServiceInitiator = DFUServiceInitiator(
            queue: queue,
            delegateQueue: queue,
            progressQueue: queue,
            loggerQueue: queue
        )
        super.init()
    }

    // MARK: - RuuviTag DFU Flash
    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        guard let uuid = UUID(uuidString: uuid)
        else {
            assertionFailure("Invalid UUID")
            return Fail<FlashResponse, Error>(error: RuuviDfuError(description: "Invalid UUID")).eraseToAnyPublisher()
        }
        let subject = PassthroughSubject<FlashResponse, Error>()
        self.subject = subject
        self.firmware = firmware
        partsCompleted = 0
        currentFirmwarePartsCompleted = 0
        dfuServiceInitiator.delegate = self
        dfuServiceInitiator.progressDelegate = self
        dfuServiceInitiator.logger = self
        dfuServiceController = dfuServiceInitiator.with(firmware: firmware).start(targetWithIdentifier: uuid)
        return subject.eraseToAnyPublisher()
    }

    // MARK: - RuuviAir File Upload
    func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURL: URL,
    ) -> AnyPublisher<FlashResponse, Error> {
        let subject = PassthroughSubject<FlashResponse, Error>()
        let transport = McuMgrBleTransport(dfuDevice.peripheral)
        self.defaultManager = DefaultManager(transport: transport)
        self.subject = subject

        do {

            let fileData = try Data(contentsOf: firmwareURL)
            self.fileData = fileData
            self.totalFileSize = fileData.count
            self.uploadStartTime = Date()

            let bleTransport = McuMgrBleTransport(dfuDevice.peripheral)

            let fsManager = FileSystemManager(transport: bleTransport)
            self.fsManager = fsManager

            let fullPath = partition + "/" + firmwareURL.lastPathComponent

            _ = fsManager.upload(
                name: fullPath,
                data: fileData,
                delegate: self
            )

        } catch {
            return Fail<FlashResponse, Error>(
                error: RuuviDfuError(description: "Failed to read file: \(error.localizedDescription)")
            ).eraseToAnyPublisher()
        }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Stop Operations
    func stopFlashFirmware(device: DFUDevice) -> Bool {
        // Try to stop legacy DFU
        if let serviceController = dfuServiceController {
            return serviceController.abort()
        }

        // Try to stop file system upload
        if let fsManager = fsManager {
            fsManager.cancelTransfer()
            self.fsManager = nil
            subject?.send(completion: .failure(RuuviDfuError(description: "Upload cancelled by user")))
            return true
        }

        return false
    }

    // MARK: - Cleanup
    private func cleanup() {
        fsManager = nil
        defaultManager = nil
        fileData = nil
        totalFileSize = 0
        uploadStartTime = nil
    }
}

// MARK: - RuuviTag DFU Delegates
extension DfuFlasher: DFUServiceDelegate {
    func dfuStateDidChange(to state: DFUState) {
        switch state {
        case .completed:
            subject?.send(.done)
            subject?.send(completion: .finished)
            cleanup()
        case .connecting:
            break
        default:
            break
        }
    }

    func dfuError(_: DFUError, didOccurWithMessage message: String) {
        subject?.send(completion: .failure(RuuviDfuError(description: message)))
        cleanup()
    }
}

extension DfuFlasher: DFUProgressDelegate {
    func dfuProgressDidChange(
        for part: Int,
        outOf totalParts: Int,
        to progress: Int,
        currentSpeedBytesPerSecond _: Double,
        avgSpeedBytesPerSecond _: Double
    ) {
        guard let parts = firmware?.parts
        else {
            return
        }
        // Update the total progress view
        let totalProgress = (Float(partsCompleted) + (Float(progress) / 100.0)) / Float(parts)
        subject?.send(.progress(Double(totalProgress)))
        // Increment the parts counter for 2-part uploads
        if progress == 100 && part == 1 && totalParts == 2 || (currentFirmwarePartsCompleted == 0 && part == 2) {
            currentFirmwarePartsCompleted += 1
            partsCompleted += 1
        }
    }
}

extension DfuFlasher: LoggerDelegate {
    func logWith(_ level: LogLevel, message: String) {
        debugPrint("\(level.name()): \(message)")
        let log = DFULog(
            message: message,
            time: Date()
        )
        subject?.send(.log(log))
    }
}

// MARK: - FileUploadDelegate
extension DfuFlasher: FileUploadDelegate {
    func uploadProgressDidChange(
        bytesSent: Int,
        fileSize: Int,
        timestamp: Date
    ) {
        let progress = Double(bytesSent) / Double(fileSize)
        subject?.send(.progress(progress))
    }

    func uploadDidFail(with error: Error) {
        let message = "File upload failed: \(error.localizedDescription)"
        subject?.send(.log(DFULog(message: message, time: Date())))
        subject?.send(completion: .failure(RuuviDfuError(description: message)))
        cleanup()
    }

    func uploadDidCancel() {
        let message = "File upload cancelled"
        subject?.send(.log(DFULog(message: message, time: Date())))
        subject?.send(completion: .failure(RuuviDfuError(description: message)))
        cleanup()
    }

    func uploadDidFinish() {
        defaultManager?.reset(callback: { [weak self] (_, _) in
            self?.subject?.send(.done)
            self?.subject?.send(completion: .finished)
            self?.cleanup()
        })
    }
}
