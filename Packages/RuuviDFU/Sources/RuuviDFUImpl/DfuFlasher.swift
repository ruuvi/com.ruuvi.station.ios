import Foundation
import RuuviDFU
import Combine
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

    override init() {
        dfuServiceInitiator = DFUServiceInitiator(queue: queue,
                                                  delegateQueue: queue,
                                                  progressQueue: queue,
                                                  loggerQueue: queue)
        super.init()
    }

    func flashFirmware(
        uuid: String,
        with firmware: DFUFirmware
    ) -> AnyPublisher<FlashResponse, Error> {
        guard let uuid = UUID(uuidString: uuid) else {
            return Fail<FlashResponse, Error>(error: RuuviDfuError.failedToConstructUUID).eraseToAnyPublisher()
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

    func stopFlashFirmware(device: DFUDevice) -> Bool {
        guard let serviceController = dfuServiceController else {
            return false
        }
        return serviceController.abort()
    }
}

extension DfuFlasher: DFUServiceDelegate {
    func dfuStateDidChange(to state: DFUState) {
        switch state {
        case .completed:
            subject?.send(.done)
            subject?.send(completion: .finished)
        case .connecting:
            subject?.send(.progress(0))
        default: break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        subject?.send(completion: .failure(RuuviDfuError(description: message)))
    }
}

extension DfuFlasher: DFUProgressDelegate {
    func dfuProgressDidChange(for part: Int,
                              outOf totalParts: Int,
                              to progress: Int,
                              currentSpeedBytesPerSecond: Double,
                              avgSpeedBytesPerSecond: Double) {
        guard let parts = firmware?.parts else {
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
