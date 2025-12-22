import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary
import RuuviOntology

final class RuuviAirShellClient: NSObject, McuMgrLogDelegate {
    private var centralManager: CBCentralManager?
    private var targetUUID: UUID?
    private var pendingLevel: String?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var transport: McuMgrBleTransport?
    private var shell: ShellManager?
    private var scanTimeoutTimer: Timer?
    private var isScanning = false
    private var didStartLookup = false

    func setLedBrightness(
        uuid: String,
        level: RuuviLedBrightnessLevel,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            guard self.completion == nil else {
                completion(.failure(UnexpectedError.callerDeinitedDuringOperation))
                return
            }
            guard let uuid = UUID(uuidString: uuid) else {
                completion(.failure(UnexpectedError.viewModelUUIDIsNil))
                return
            }
            self.targetUUID = uuid
            self.pendingLevel = level.shellArgument
            self.completion = completion
            self.startCentralManager()
        }
    }

    func setLedBrightness(
        peripheral: CBPeripheral,
        level: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            let transport = McuMgrBleTransport(peripheral)
            transport.logDelegate = self

            let shell = ShellManager(transport: transport)
            shell.logDelegate = self

            self.transport = transport
            self.shell = shell

            shell.execute(
                command: "ruuvi",
                arguments: ["led_brightness", level]
            ) { [weak self] response, error in
                guard let self else { return }
                defer {
                    transport.close()
                    self.transport = nil
                    self.shell = nil
                }

                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let responseError = response?.getError() {
                    completion(.failure(responseError))
                    return
                }
                completion(.success(()))
            }
        }
    }

    func minLogLevel() -> McuMgrLogLevel { .debug }

    func log(
        _ msg: String,
        ofCategory category: McuMgrLogCategory,
        atLevel level: McuMgrLogLevel
    ) {
#if DEBUG || ALPHA
        print("[RuuviAirShellClient Log] - [\(category) \(level)] \(msg)")
#endif
    }
}

extension RuuviAirShellClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startPeripheralLookup()
        case .unsupported, .unauthorized, .poweredOff:
            finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        guard let targetUUID else { return }
        guard peripheral.identifier == targetUUID else { return }
        stopScan()
        guard let level = pendingLevel else {
            finish(with: .failure(UnexpectedError.callbackErrorAndResultAreNil))
            return
        }
        setLedBrightness(peripheral: peripheral, level: level) { [weak self] result in
            self?.finish(with: result)
        }
    }
}

private extension RuuviAirShellClient {
    func startCentralManager() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
            return
        }
        if centralManager?.state == .poweredOn {
            startPeripheralLookup()
        }
    }

    func startPeripheralLookup() {
        guard !didStartLookup else { return }
        didStartLookup = true
        guard let centralManager, let targetUUID else {
            finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
            return
        }

        if let peripheral = centralManager.retrievePeripherals(
            withIdentifiers: [targetUUID]
        ).first {
            guard let level = pendingLevel else {
                finish(with: .failure(UnexpectedError.callbackErrorAndResultAreNil))
                return
            }
            setLedBrightness(peripheral: peripheral, level: level) { [weak self] result in
                self?.finish(with: result)
            }
            return
        }

        startScan()
    }

    func startScan() {
        guard let centralManager, !isScanning else { return }
        isScanning = true
        centralManager.scanForPeripherals(withServices: nil)
        scanTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: 6,
            repeats: false
        ) { [weak self] _ in
            self?.finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
        }
    }

    func stopScan() {
        guard let centralManager, isScanning else { return }
        centralManager.stopScan()
        isScanning = false
    }

    func finish(with result: Result<Void, Error>) {
        stopScan()
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        didStartLookup = false

        let completion = completion
        self.completion = nil
        targetUUID = nil
        pendingLevel = nil
        centralManager = nil

        DispatchQueue.main.async {
            completion?(result)
        }
    }
}
