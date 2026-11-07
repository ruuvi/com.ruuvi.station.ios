import CoreBluetooth
import Foundation
import RuuviOntology

final class RuuviAirShellClient {
    private let makeTransport: () -> RuuviAirShellTransport
    private let scanTimeout: TimeInterval
    private var transport: RuuviAirShellTransport?
    private var targetUUID: UUID?
    private var pendingLevel: String?
    private var completion: ((Result<Void, Error>) -> Void)?
    private var scanTimeoutTimer: Timer?
    private var isScanning = false
    private var didStartLookup = false
    private var isWriting = false
    private var operationID: UUID?

    init(
        makeTransport: @escaping () -> RuuviAirShellTransport = { CoreBluetoothAirShellTransport() },
        scanTimeout: TimeInterval = 6
    ) {
        self.makeTransport = makeTransport
        self.scanTimeout = scanTimeout
    }

    deinit {
        let timer = scanTimeoutTimer
        let transport = transport
        let cleanup = {
            timer?.invalidate(); transport?.stop()
        }
        if Thread.isMainThread { cleanup() } else { DispatchQueue.main.async(execute: cleanup) }
    }

    private func receive(for operationID: UUID, action: @escaping (RuuviAirShellClient) -> Void) {
        let deliver = { [weak self] in
            guard let self, self.operationID == operationID else { return }
            action(self)
        }
        if Thread.isMainThread { deliver() } else { DispatchQueue.main.async(execute: deliver) }
    }

    func setLedBrightness(
        uuid: String, level: RuuviLedBrightnessLevel,
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
            let operationID = UUID()
            self.operationID = operationID
            self.targetUUID = uuid
            self.pendingLevel = level.shellArgument
            self.completion = completion
            let transport = self.makeTransport()
            self.transport = transport
            transport.start(
                stateChanged: { [weak self] state in
                    self?.receive(for: operationID) { $0.receive(state: state) }
                },
                discovered: { [weak self] peripheral in
                    self?.receive(for: operationID) { $0.receive(peripheral: peripheral) }
                })
        }
    }

    private func receive(state: CBManagerState) {
        switch state {
        case .poweredOn: startPeripheralLookup()
        case .unsupported, .unauthorized, .poweredOff:
            finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
        default: break
        }
    }

    private func startPeripheralLookup() {
        guard !didStartLookup else { return }
        didStartLookup = true
        guard let transport, let targetUUID, let operationID else {
            finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
            return
        }
        if let peripheral = transport.retrieve(targetUUID) {
            write(to: peripheral)
        } else {
            isScanning = true
            scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: scanTimeout, repeats: false) { [weak self] _ in
                self?.receive(for: operationID) {
                    $0.finish(with: .failure(UnexpectedError.failedToFindRuuviTag))
                }
            }
            transport.scan()
        }
    }

    private func receive(peripheral: RuuviAirShellPeripheral) {
        guard !isWriting, peripheral.identifier == targetUUID else { return }
        stopScan()
        write(to: peripheral)
    }

    private func write(to peripheral: RuuviAirShellPeripheral) {
        guard !isWriting, let operationID else { return }
        guard let level = pendingLevel else {
            finish(with: .failure(UnexpectedError.callbackErrorAndResultAreNil))
            return
        }
        isWriting = true
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        transport?.execute(on: peripheral, command: "ruuvi", arguments: ["led_brightness", level]) {
            [weak self] result in
            self?.receive(for: operationID) { $0.finish(with: result) }
        }
    }

    private func stopScan() {
        guard isScanning else { return }
        transport?.stopScan()
        isScanning = false
    }

    private func finish(with result: Result<Void, Error>) {
        guard operationID != nil else { return }
        operationID = nil
        let transport = transport
        self.transport = nil
        let wasScanning = isScanning
        isScanning = false
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        didStartLookup = false
        isWriting = false
        let completion = completion
        self.completion = nil
        targetUUID = nil
        pendingLevel = nil
        if wasScanning { transport?.stopScan() }
        transport?.stop()
        DispatchQueue.main.async { completion?(result) }
    }
}
