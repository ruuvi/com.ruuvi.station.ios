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
    private var dfuServiceController: DFUServiceController?
    private var subject: PassthroughSubject<FlashResponse, Error>?

    // MCUManager properties
    private var fsManager: FileSystemManager?
    private var defaultManager: DefaultManager?
    private var bleTransport: McuMgrBleTransport?

    private var firmwareUploads: [FirmwareUpload] = []
    private var currentUploadIndex: Int = 0
    private var totalBatchBytes: Int = 0
    private var uploadedBatchBytes: Int = 0
    private var lastLoggedOverallProgress: Int = -1

    private struct FilesController {
        static let partitionKey = "partition_key"
        static let defaultPartition = "/lfs1"
    }

    private struct FirmwareUpload {
        let path: String
        let data: Data
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

    // MARK: - RuuviTag DFU Flash (Legacy Nordic DFU)
    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        guard let uuid = UUID(uuidString: uuid)
        else {
            assertionFailure("Invalid UUID")
            return Fail(error: RuuviDfuError(description: "Invalid UUID"))
                .eraseToAnyPublisher()
        }
        let subject = PassthroughSubject<FlashResponse, Error>()
        self.subject = subject
        self.firmware = firmware
        partsCompleted = 0
        dfuServiceInitiator.delegate = self
        dfuServiceInitiator.progressDelegate = self
        dfuServiceInitiator.logger = self
        dfuServiceController = dfuServiceInitiator
            .with(firmware: firmware)
            .start(targetWithIdentifier: uuid)
        return subject.eraseToAnyPublisher()
    }

    // MARK: - RuuviAir Firmware Upload (McuManager FileSystemManager)
    func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURL: URL
    ) -> AnyPublisher<FlashResponse, Error> {
        flashFirmware(dfuDevice: dfuDevice, with: [firmwareURL])
    }

    func flashFirmware(
        dfuDevice: DFUDevice,
        with firmwareURLs: [URL]
    ) -> AnyPublisher<FlashResponse, Error> {
        guard !firmwareURLs.isEmpty else {
            return Fail(error: RuuviDfuError(description: "No firmware files provided"))
                .eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<FlashResponse, Error>()
        self.subject = subject

        do {
            let transport = McuMgrBleTransport(dfuDevice.peripheral)
            defaultManager = DefaultManager(transport: transport)
            bleTransport = transport
            fsManager = FileSystemManager(transport: transport)

            // Load and validate ALL files upfront
            firmwareUploads = []
            for url in firmwareURLs {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw RuuviDfuError(description: "File does not exist: \(url.lastPathComponent)")
                }

                let data = try Data(contentsOf: url)
                let fullPath = partition + "/" + url.lastPathComponent
                firmwareUploads.append(FirmwareUpload(path: fullPath, data: data))
            }

            guard !firmwareUploads.isEmpty else {
                throw RuuviDfuError(description: "No firmware data available")
            }

            totalBatchBytes = firmwareUploads.reduce(0) { $0 + $1.data.count }
            uploadedBatchBytes = 0
            currentUploadIndex = 0
            lastLoggedOverallProgress = -1

            startNextUpload()

        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }

        return subject.eraseToAnyPublisher()
    }

    // MARK: - Stop Operations
    func stopFlashFirmware(device: DFUDevice) -> Bool {
        // Nordic DFU
        if let serviceController = dfuServiceController {
            return serviceController.abort()
        }
        // FileSystemManager
        if let fsManager = fsManager {
            fsManager.cancelTransfer()
            self.fsManager = nil
            subject?.send(completion: .failure(RuuviDfuError(description: "Upload cancelled by user")))
            cleanup()
            return true
        }
        return false
    }

    // MARK: - Upload Execution
    private func startNextUpload() {
        guard currentUploadIndex < firmwareUploads.count else {
            finishUploads()
            return
        }

        guard let transport = bleTransport else {
            subject?.send(completion: .failure(RuuviDfuError(description: "Transport unavailable")))
            cleanup()
            return
        }

        // Create NEW FileSystemManager for each upload
        fsManager = FileSystemManager(transport: transport)

        let upload = firmwareUploads[currentUploadIndex]
        let started = fsManager?.upload(
            name: upload.path,
            data: upload.data,
            delegate: self
        )

        if started != true {
            subject?
                .send(
                    completion: .failure(
                        RuuviDfuError(
                            description: "Failed to start upload for \(upload.path)."
                        )
                    )
                )
            cleanup()
        }
    }

    // MARK: - Finish
    private func finishUploads() {
        if totalBatchBytes > 0 {
            subject?.send(.progress(1.0))
        }
        guard let defaultManager = defaultManager else {
            subject?.send(.done)
            subject?.send(completion: .finished)
            cleanup()
            return
        }
        defaultManager.reset { [weak self] _, _ in
            guard let self = self else { return }
            self.subject?.send(.done)
            self.subject?.send(completion: .finished)
            self.cleanup()
        }
    }

    private func cleanup() {
        fsManager = nil
        defaultManager = nil
        bleTransport = nil
        firmwareUploads = []
        currentUploadIndex = 0
        totalBatchBytes = 0
        uploadedBatchBytes = 0
        lastLoggedOverallProgress = -1
    }
}

// MARK: - Nordic DFU Delegates
extension DfuFlasher: DFUServiceDelegate {
    func dfuStateDidChange(to state: DFUState) {
        if state == .completed {
            subject?.send(.done)
            subject?.send(completion: .finished)
            cleanup()
        }
    }
    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
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
        guard let parts = firmware?.parts else { return }
        let totalProgress = (Float(partsCompleted) + (Float(progress) / 100.0)) / Float(parts)
        subject?.send(.progress(Double(totalProgress)))
        if progress == 100 && part == 1 && totalParts == 2 {
            partsCompleted += 1
        }
    }
}

extension DfuFlasher: LoggerDelegate {
    func logWith(_ level: LogLevel, message: String) {
        debugPrint("\(level.name()): \(message)")
        subject?.send(.log(DFULog(message: message, time: Date())))
    }
}

// MARK: - FileSystemManager Delegate
extension DfuFlasher: FileUploadDelegate {
    func uploadProgressDidChange(bytesSent: Int, fileSize: Int, timestamp: Date) {
        guard totalBatchBytes > 0 else { return }
        let completedBytes = uploadedBatchBytes + bytesSent
        let overall = Double(completedBytes) / Double(totalBatchBytes)

        let overallPercent = Int(overall * 100)
        if overallPercent != lastLoggedOverallProgress {
            lastLoggedOverallProgress = overallPercent
        }

        subject?.send(.progress(overall))
    }

    func uploadDidFail(with error: Error) {
        subject?.send(completion: .failure(error))
        cleanup()
    }

    func uploadDidCancel() {
        subject?.send(completion: .failure(RuuviDfuError(description: "Upload cancelled")))
        cleanup()
    }

    func uploadDidFinish() {
        uploadedBatchBytes += firmwareUploads[currentUploadIndex].data.count
        currentUploadIndex += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startNextUpload()
        }
    }
}
