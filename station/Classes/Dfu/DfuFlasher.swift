import Foundation
import NordicDFU

protocol DfuFlasherOutputProtocol: AnyObject {
    func ruuviDfuDidUpdateProgress(percentage: Float)
    func ruuviDfuDidUpdateLog(log: DfuLog)
    func ruuviDfuDidFinish()
    func ruuviDfuError(error: Error)
}

class DfuFlasher: NSObject {
    private let queue = DispatchQueue(label: "DfuFlasher", qos: .userInteractive)
    private var dfuServiceInitiator: DFUServiceInitiator
    private weak var output: DfuFlasherOutputProtocol?
    private var firmware: DFUFirmware?
    private var partsCompleted: Int = 0
    private var currentFirmwarePartsCompleted: Int = 0
    private var dfuServiceController: DFUServiceController?

    override init() {
        dfuServiceInitiator = DFUServiceInitiator(queue: queue,
                                                  delegateQueue: queue,
                                                  progressQueue: queue,
                                                  loggerQueue: queue)
        super.init()
    }

    func flashFirmware(device: DfuDevice,
                       with firmware: DFUFirmware,
                       output: DfuFlasherOutputProtocol) {
        guard let uuid = UUID(uuidString: device.uuid) else {
            return
        }
        self.firmware = firmware
        self.output = output
        partsCompleted = 0
        currentFirmwarePartsCompleted = 0
        dfuServiceInitiator.delegate = self
        dfuServiceInitiator.progressDelegate = self
        dfuServiceInitiator.logger = self
        dfuServiceController = dfuServiceInitiator.with(firmware: firmware)
            .start(targetWithIdentifier: uuid)
    }

    func stopFlashFirmware(device: DfuDevice) -> Bool {
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
            output?.ruuviDfuDidFinish()
        case .connecting:
            output?.ruuviDfuDidUpdateProgress(percentage: 0)
        default: break
        }
    }

    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        output?.ruuviDfuError(error: RuuviDfuError(description: message))
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
        output?.ruuviDfuDidUpdateProgress(percentage: totalProgress)
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
        output?.ruuviDfuDidUpdateLog(log: DfuLog(
            message: message,
            time: Date()
        ))
    }
}
