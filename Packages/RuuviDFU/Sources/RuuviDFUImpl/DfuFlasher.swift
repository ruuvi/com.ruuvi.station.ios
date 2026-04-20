import Combine
import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary
#if canImport(NordicDFU)
import NordicDFU
#endif
#if canImport(iOSDFULibrary)
import iOSDFULibrary
#endif

class DfuFlasher: NSObject {
    private let queue: DispatchQueue
    private let legacyStarter: DfuLegacyServiceStarting
    private let uploadSessionBuilder: DfuUploadSessionBuilding
    private let fileExists: (String) -> Bool
    private let loadData: (URL) throws -> Data
    private let scheduleNextUpload: (@escaping () -> Void) -> Void
    private var firmware: DFUFirmware?
    private var partsCompleted: Int = 0
    private var dfuServiceController: DfuServiceControlling?
    private var subject: PassthroughSubject<FlashResponse, Error>?

    // MCUManager properties
    private var fsManager: DfuFileSystemManaging?
    private var uploadSession: DfuUploadSession?

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

    static func defaultScheduleNextUpload(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private var partition: String {
        return UserDefaults.standard
            .string(forKey: FilesController.partitionKey)
            ?? FilesController.defaultPartition
    }

    override convenience init() {
        let queue = DispatchQueue(label: "DfuFlasher", qos: .userInteractive)
        self.init(
            queue: queue,
            legacyStarter: NordicDfuLegacyStarter(queue: queue),
            uploadSessionBuilder: DefaultDfuUploadSessionBuilder()
        )
    }

    init(
        queue: DispatchQueue = DispatchQueue(label: "DfuFlasher", qos: .userInteractive),
        legacyStarter: DfuLegacyServiceStarting,
        uploadSessionBuilder: DfuUploadSessionBuilding,
        fileExists: @escaping (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
        loadData: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
        scheduleNextUpload: @escaping (@escaping () -> Void) -> Void = DfuFlasher.defaultScheduleNextUpload
    ) {
        self.queue = queue
        self.legacyStarter = legacyStarter
        self.uploadSessionBuilder = uploadSessionBuilder
        self.fileExists = fileExists
        self.loadData = loadData
        self.scheduleNextUpload = scheduleNextUpload
        super.init()
    }

    // MARK: - RuuviTag DFU Flash (Legacy Nordic DFU)
    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        guard let uuid = UUID(uuidString: uuid)
        else {
            return Fail(error: RuuviDfuError(description: "Invalid UUID"))
                .eraseToAnyPublisher()
        }
        let subject = PassthroughSubject<FlashResponse, Error>()
        self.subject = subject
        self.firmware = firmware
        partsCompleted = 0
        legacyStarter.delegate = self
        legacyStarter.progressDelegate = self
        legacyStarter.logger = self
        dfuServiceController = legacyStarter.start(firmware: firmware, targetIdentifier: uuid)
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
            uploadSession = try uploadSessionBuilder.makeSession(for: dfuDevice.peripheral)

            // Load and validate ALL files upfront
            firmwareUploads = []
            for url in firmwareURLs {
                guard fileExists(url.path) else {
                    throw RuuviDfuError(description: "File does not exist: \(url.lastPathComponent)")
                }

                let data = try loadData(url)
                let fullPath = partition + "/" + url.lastPathComponent
                firmwareUploads.append(FirmwareUpload(path: fullPath, data: data))
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

        guard let uploadSession else {
            subject?.send(completion: .failure(RuuviDfuError(description: "Upload session unavailable")))
            cleanup()
            return
        }

        // Create NEW FileSystemManager for each upload
        let fileSystemManager = uploadSession.makeFileSystemManager()
        fsManager = fileSystemManager

        let upload = firmwareUploads[currentUploadIndex]
        let started = fileSystemManager.upload(
            name: upload.path,
            data: upload.data,
            delegate: self
        )

        if !started {
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
        guard let resetManager = uploadSession?.resetManager else {
            subject?.send(.done)
            subject?.send(completion: .finished)
            cleanup()
            return
        }
        resetManager.reset { [weak self] in
            guard let self = self else { return }
            self.subject?.send(.done)
            self.subject?.send(completion: .finished)
            self.cleanup()
        }
    }

    private func cleanup() {
        fsManager = nil
        uploadSession = nil
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
        scheduleNextUpload { [weak self] in
            self?.startNextUpload()
        }
    }
}

protocol DfuServiceControlling {
    func abort() -> Bool
}

protocol DfuLegacyServiceStarting: AnyObject {
    var delegate: DFUServiceDelegate? { get set }
    var progressDelegate: DFUProgressDelegate? { get set }
    var logger: LoggerDelegate? { get set }
    func start(firmware: DFUFirmware, targetIdentifier: UUID) -> DfuServiceControlling?
}

protocol DfuFileSystemManaging: AnyObject {
    @discardableResult
    func upload(name: String, data: Data, delegate: FileUploadDelegate) -> Bool
    func cancelTransfer()
}

protocol DfuResetManaging: AnyObject {
    func reset(completion: @escaping () -> Void)
}

protocol DfuUploadSession: AnyObject {
    var resetManager: DfuResetManaging { get }
    func makeFileSystemManager() -> DfuFileSystemManaging
}

protocol DfuUploadSessionBuilding {
    func makeSession(for peripheral: CBPeripheral) throws -> DfuUploadSession
}

protocol NordicDfuTargetStarting {
    func start(targetWithIdentifier: UUID) -> NordicDfuServiceControlling?
}

protocol NordicDfuServiceInitiating: AnyObject {
    var delegate: DFUServiceDelegate? { get set }
    var progressDelegate: DFUProgressDelegate? { get set }
    var logger: LoggerDelegate? { get set }
    func makeStarter(firmware: DFUFirmware) -> NordicDfuTargetStarting
}

protocol NordicDfuServiceControlling: AnyObject {
    func abort() -> Bool
}

extension DFUServiceController: NordicDfuServiceControlling {}

extension DFUServiceInitiator: NordicDfuTargetStarting {
    func start(targetWithIdentifier: UUID) -> NordicDfuServiceControlling? {
        let controller: DFUServiceController? = self.start(targetWithIdentifier: targetWithIdentifier)
        return controller
    }
}

extension DFUServiceInitiator: NordicDfuServiceInitiating {
    func makeStarter(firmware: DFUFirmware) -> NordicDfuTargetStarting {
        self.with(firmware: firmware)
    }
}

protocol DfuTransporting: AnyObject, McuMgrTransport {}

extension McuMgrBleTransport: DfuTransporting {}

final class NordicDfuLegacyStarter: DfuLegacyServiceStarting {
    private let initiator: NordicDfuServiceInitiating

    init(queue: DispatchQueue) {
        initiator = DFUServiceInitiator(
            queue: queue,
            delegateQueue: queue,
            progressQueue: queue,
            loggerQueue: queue
        )
    }

    init(initiator: NordicDfuServiceInitiating) {
        self.initiator = initiator
    }

    var delegate: DFUServiceDelegate? {
        get { initiator.delegate }
        set { initiator.delegate = newValue }
    }

    var progressDelegate: DFUProgressDelegate? {
        get { initiator.progressDelegate }
        set { initiator.progressDelegate = newValue }
    }

    var logger: LoggerDelegate? {
        get { initiator.logger }
        set { initiator.logger = newValue }
    }

    func start(firmware: DFUFirmware, targetIdentifier: UUID) -> DfuServiceControlling? {
        initiator
            .makeStarter(firmware: firmware)
            .start(targetWithIdentifier: targetIdentifier)
            .map(DfuServiceControllerAdapter.init)
    }
}

final class DfuServiceControllerAdapter: DfuServiceControlling {
    private let controller: NordicDfuServiceControlling

    init(controller: NordicDfuServiceControlling) {
        self.controller = controller
    }

    func abort() -> Bool {
        controller.abort()
    }
}

struct DefaultDfuUploadSessionBuilder: DfuUploadSessionBuilding {
    private let sessionFactory: (CBPeripheral) -> DfuUploadSession

    init(
        sessionFactory: @escaping (CBPeripheral) -> DfuUploadSession = {
            McuManagerDfuUploadSession(peripheral: $0)
        }
    ) {
        self.sessionFactory = sessionFactory
    }

    init(
        transportFactory: @escaping (CBPeripheral) -> DfuTransporting,
        resetManagerFactory: @escaping (DfuTransporting) -> DfuResetManaging = { transport in
            DefaultManagerAdapter(manager: DefaultManager(transport: transport))
        },
        fileSystemManagerFactory: @escaping (DfuTransporting) -> DfuFileSystemManaging = {
            transport in
            FileSystemManagerAdapter(manager: FileSystemManager(transport: transport))
        }
    ) {
        sessionFactory = { peripheral in
            McuManagerDfuUploadSession(
                peripheral: peripheral,
                transportFactory: transportFactory,
                resetManagerFactory: resetManagerFactory,
                fileSystemManagerFactory: fileSystemManagerFactory
            )
        }
    }

    func makeSession(for peripheral: CBPeripheral) throws -> DfuUploadSession {
        sessionFactory(peripheral)
    }
}

final class McuManagerDfuUploadSession: DfuUploadSession {
    let resetManager: DfuResetManaging
    private let fileSystemManagerFactory: () -> DfuFileSystemManaging

    init(
        peripheral: CBPeripheral,
        transportFactory: @escaping (CBPeripheral) -> DfuTransporting = {
            McuMgrBleTransport($0)
        },
        resetManagerFactory: @escaping (DfuTransporting) -> DfuResetManaging = { transport in
            DefaultManagerAdapter(manager: DefaultManager(transport: transport))
        },
        fileSystemManagerFactory: @escaping (DfuTransporting) -> DfuFileSystemManaging = {
            transport in
            return FileSystemManagerAdapter(manager: FileSystemManager(transport: transport))
        }
    ) {
        let transport = transportFactory(peripheral)
        resetManager = resetManagerFactory(transport)
        self.fileSystemManagerFactory = {
            fileSystemManagerFactory(transport)
        }
    }

    func makeFileSystemManager() -> DfuFileSystemManaging {
        fileSystemManagerFactory()
    }
}

final class DefaultManagerAdapter: DfuResetManaging {
    private let resetClosure: (@escaping () -> Void) -> Void

    init(manager: DefaultManager) {
        resetClosure = { completion in
            manager.reset { _, _ in
                completion()
            }
        }
    }

    init(resetClosure: @escaping (@escaping () -> Void) -> Void) {
        self.resetClosure = resetClosure
    }

    func reset(completion: @escaping () -> Void) {
        resetClosure(completion)
    }
}

final class FileSystemManagerAdapter: DfuFileSystemManaging {
    private let uploadClosure: (String, Data, FileUploadDelegate) -> Bool
    private let cancelClosure: () -> Void

    init(manager: FileSystemManager) {
        uploadClosure = { name, data, delegate in
            manager.upload(name: name, data: data, delegate: delegate)
        }
        cancelClosure = {
            manager.cancelTransfer()
        }
    }

    init(
        uploadClosure: @escaping (String, Data, FileUploadDelegate) -> Bool,
        cancelClosure: @escaping () -> Void
    ) {
        self.uploadClosure = uploadClosure
        self.cancelClosure = cancelClosure
    }

    @discardableResult
    func upload(name: String, data: Data, delegate: FileUploadDelegate) -> Bool {
        uploadClosure(name, data, delegate)
    }

    func cancelTransfer() {
        cancelClosure()
    }
}
