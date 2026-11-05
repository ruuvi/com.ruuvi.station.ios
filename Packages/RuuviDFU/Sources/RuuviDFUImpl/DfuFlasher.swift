#if SWIFT_PACKAGE
    import RuuviDFU
#endif
import Combine
import Foundation
#if canImport(NordicDFU)
    import NordicDFU
#endif
#if canImport(iOSDFULibrary)
    import iOSDFULibrary
#endif

protocol DFULegacyFlashing: AnyObject {
    func start(
        uuid: UUID, firmware: DFUFirmware, event: @escaping (FlashResponse) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool
    func cancel() -> Bool
}

protocol DFUFileTransport: AnyObject {
    func upload(
        path: String, data: Data, progress: @escaping (Int) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool
    func reset(completion: @escaping (Error?) -> Void)
    func cancel()
}

/// Serializes each upgrade and rejects callbacks belonging to a previous session.
final class DfuFlasher {
    private struct Upload {
        let path: String
        let data: Data
    }
    private final class Operation {
        let id: UUID
        let deviceID: String
        let subject: PassthroughSubject<FlashResponse, Error>
        var legacy: DFULegacyFlashing?
        var transport: DFUFileTransport?
        var uploads: [Upload] = []
        var index = 0
        var uploadedBytes = 0
        var totalBytes = 0
        var progress = 0.0
        var awaitingUpload = false
        init(id: UUID, deviceID: String, subject: PassthroughSubject<FlashResponse, Error>) {
            self.id = id
            self.deviceID = deviceID
            self.subject = subject
        }
    }
    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Bool>()
    private let legacyFactory: () -> DFULegacyFlashing
    private let transportFactory: (DFUDevice) throws -> DFUFileTransport
    private let partition: () -> String
    private let nextUploadDelay: TimeInterval
    private var operation: Operation?

    init(
        queue: DispatchQueue = DispatchQueue(label: "DfuFlasher", qos: .userInteractive),
        legacyFactory: (() -> DFULegacyFlashing)? = nil,
        transportFactory: @escaping (DFUDevice) throws -> DFUFileTransport = DFUMcuTransport.init,
        partition: @escaping () -> String = {
            UserDefaults.standard.string(forKey: "partition_key") ?? "/lfs1"
        },
        nextUploadDelay: TimeInterval = 0.5
    ) {
        self.queue = queue
        self.legacyFactory = legacyFactory ?? { DFUNordicTransport(queue: queue) }
        self.transportFactory = transportFactory
        self.partition = partition
        self.nextUploadDelay = nextUploadDelay
        queue.setSpecific(key: queueKey, value: true)
    }

    deinit {
        let operation = operation
        queue.async {
            _ = operation?.legacy?.cancel()
            operation?.transport?.cancel()
            operation?.subject.send(completion: .failure(RuuviDfuError(description: "Firmware update closed")))
        }
    }

    func flashFirmware(uuid: String, with firmware: DFUFirmware) -> AnyPublisher<FlashResponse, Error> {
        publisher { flasher, id, subject in
            guard let uuid = UUID(uuidString: uuid) else {
                subject.send(completion: .failure(RuuviDfuError(description: "Invalid UUID")))
                return
            }
            guard let operation = flasher.begin(id: id, deviceID: uuid.uuidString, subject: subject) else { return }
            let transport = flasher.legacyFactory()
            operation.legacy = transport
            let started = transport.start(
                uuid: uuid, firmware: firmware,
                event: { [weak flasher] event in
                    flasher?.queue.async { [weak flasher] in flasher?.receive(event, id: id) }
                },
                completion: { [weak flasher] result in
                    flasher?.queue.async { [weak flasher] in flasher?.complete(id: id, result: result) }
                })
            if !started {
                flasher.complete(
                    id: id, result: .failure(RuuviDfuError(description: "Failed to start firmware update")))
            }
        }
    }

    func flashFirmware(dfuDevice: DFUDevice, with firmwareURL: URL) -> AnyPublisher<FlashResponse, Error> {
        flashFirmware(dfuDevice: dfuDevice, with: [firmwareURL])
    }

    func flashFirmware(dfuDevice: DFUDevice, with firmwareURLs: [URL]) -> AnyPublisher<FlashResponse, Error> {
        publisher { flasher, id, subject in
            guard let operation = flasher.begin(id: id, deviceID: dfuDevice.uuid, subject: subject) else { return }
            do {
                guard !firmwareURLs.isEmpty else { throw RuuviDfuError(description: "No firmware files provided") }
                let partition = flasher.partition().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                for url in firmwareURLs {
                    let data = try Data(contentsOf: url)
                    guard !data.isEmpty else {
                        throw RuuviDfuError(description: "Empty firmware file: \(url.lastPathComponent)")
                    }
                    operation.uploads.append(Upload(path: "/" + partition + "/" + url.lastPathComponent, data: data))
                    operation.totalBytes += data.count
                }
                operation.transport = try flasher.transportFactory(dfuDevice)
                flasher.startNextUpload(id: id)
            } catch {
                flasher.complete(id: id, result: .failure(error))
            }
        }
    }

    func stopFlashFirmware(device: DFUDevice) -> Bool {
        onQueue {
            guard let operation, operation.deviceID == device.uuid else { return false }
            return cancel(id: operation.id)
        }
    }

    private func onQueue<T>(_ action: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true { return action() }
        return queue.sync(execute: action)
    }

    private func publisher(
        start: @escaping (DfuFlasher, UUID, PassthroughSubject<FlashResponse, Error>) -> Void
    ) -> AnyPublisher<FlashResponse, Error> {
        Deferred { [weak self] () -> AnyPublisher<FlashResponse, Error> in
            let subject = PassthroughSubject<FlashResponse, Error>()
            let id = UUID()
            let gate = DFUStartGate()
            return subject.handleEvents(
                receiveCancel: { [weak self] in
                    self?.queue.async { [weak self] in _ = self?.cancel(id: id, force: true) }
                },
                receiveRequest: { [weak self] _ in
                    guard gate.claim() else { return }
                    guard let self else {
                        subject.send(completion: .failure(RuuviDfuError(description: "Firmware update closed")))
                        return
                    }
                    self.queue.async { start(self, id, subject) }
                }
            ).eraseToAnyPublisher()
        }.eraseToAnyPublisher()
    }

    private func begin(
        id: UUID, deviceID: String, subject: PassthroughSubject<FlashResponse, Error>
    ) -> Operation? {
        guard operation == nil else {
            subject.send(completion: .failure(RuuviDfuError(description: "A firmware update is already running")))
            return nil
        }
        let operation = Operation(id: id, deviceID: deviceID, subject: subject)
        self.operation = operation
        return operation
    }

    private func cancel(id: UUID, force: Bool = false) -> Bool {
        guard let operation, operation.id == id else { return false }
        if let legacy = operation.legacy, !legacy.cancel(), !force { return false }
        operation.transport?.cancel()
        complete(id: id, result: .failure(RuuviDfuError(description: "Upload cancelled by user")))
        return true
    }

    private func receive(_ event: FlashResponse, id: UUID) {
        guard let operation, operation.id == id else { return }
        switch event {
        case .progress(let value):
            guard value.isFinite else { return }
            operation.progress = max(operation.progress, min(1, max(0, value)))
            operation.subject.send(.progress(operation.progress))
        case .log:
            operation.subject.send(event)
        case .done:
            complete(id: id, result: .success(()))
        }
    }

    private func startNextUpload(id: UUID) {
        guard let operation, operation.id == id, let transport = operation.transport else { return }
        guard operation.index < operation.uploads.count else {
            transport.reset { [weak self] error in
                self?.queue.async { [weak self] in
                    self?.complete(id: id, result: error.map { .failure($0) } ?? .success(()))
                }
            }
            return
        }
        let index = operation.index
        let upload = operation.uploads[index]
        operation.awaitingUpload = true
        let started = transport.upload(
            path: upload.path, data: upload.data,
            progress: { [weak self] bytes in
                self?.queue.async { [weak self] in self?.uploadProgress(id: id, index: index, bytes: bytes) }
            },
            completion: { [weak self] result in
                self?.queue.async { [weak self] in self?.uploadCompleted(id: id, index: index, result: result) }
            })
        if !started {
            complete(id: id, result: .failure(RuuviDfuError(description: "Failed to start upload for \(upload.path)")))
        }
    }

    private func uploadProgress(id: UUID, index: Int, bytes: Int) {
        guard let operation, operation.id == id, operation.index == index, operation.awaitingUpload else { return }
        let bounded = min(operation.uploads[index].data.count, max(0, bytes))
        let progress = Double(operation.uploadedBytes + bounded) / Double(operation.totalBytes)
        receive(.progress(progress), id: id)
    }

    private func uploadCompleted(id: UUID, index: Int, result: Result<Void, Error>) {
        guard let operation, operation.id == id, operation.index == index, operation.awaitingUpload else { return }
        operation.awaitingUpload = false
        switch result {
        case .failure:
            complete(id: id, result: result)
        case .success:
            operation.uploadedBytes += operation.uploads[index].data.count
            operation.index += 1
            receive(.progress(Double(operation.uploadedBytes) / Double(operation.totalBytes)), id: id)
            queue.asyncAfter(deadline: .now() + nextUploadDelay) { [weak self] in self?.startNextUpload(id: id) }
        }
    }

    private func complete(id: UUID, result: Result<Void, Error>) {
        guard let operation, operation.id == id else { return }
        self.operation = nil
        switch result {
        case .success:
            operation.subject.send(.progress(1))
            operation.subject.send(.done)
            operation.subject.send(completion: .finished)
        case .failure(let error):
            operation.subject.send(completion: .failure(error))
        }
    }
}

private final class DFUStartGate {
    private let lock = NSLock()
    private var started = false
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !started else { return false }
        started = true
        return true
    }
}
