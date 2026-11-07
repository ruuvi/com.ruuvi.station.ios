import CoreBluetooth
import Foundation
import iOSMcuManagerLibrary
import RuuviOntology

struct RuuviAirShellPeripheral {
    let identifier: UUID
    let peripheral: CBPeripheral?
    init(identifier: UUID, peripheral: CBPeripheral? = nil) {
        self.identifier = identifier
        self.peripheral = peripheral
    }
}

protocol RuuviAirShellTransport: AnyObject {
    func start(
        stateChanged: @escaping (CBManagerState) -> Void, discovered: @escaping (RuuviAirShellPeripheral) -> Void)
    func retrieve(_ identifier: UUID) -> RuuviAirShellPeripheral?
    func scan()
    func stopScan()
    func execute(
        on peripheral: RuuviAirShellPeripheral, command: String, arguments: [String],
        completion: @escaping (Result<Void, Error>) -> Void)
    func stop()
}

final class CoreBluetoothAirShellTransport: NSObject, RuuviAirShellTransport {
    private var central: CBCentralManager?
    private var transport: McuMgrBleTransport?
    private var shell: ShellManager?
    private var stateChanged: ((CBManagerState) -> Void)?
    private var discovered: ((RuuviAirShellPeripheral) -> Void)?

    func start(
        stateChanged: @escaping (CBManagerState) -> Void, discovered: @escaping (RuuviAirShellPeripheral) -> Void
    ) {
        self.stateChanged = stateChanged
        self.discovered = discovered
        central = CBCentralManager(delegate: self, queue: nil)
    }
    func retrieve(_ identifier: UUID) -> RuuviAirShellPeripheral? {
        central?.retrievePeripherals(withIdentifiers: [identifier]).first.map {
            RuuviAirShellPeripheral(identifier: $0.identifier, peripheral: $0)
        }
    }
    func scan() { central?.scanForPeripherals(withServices: nil) }
    func stopScan() { central?.stopScan() }
    func execute(
        on peripheral: RuuviAirShellPeripheral, command: String, arguments: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let peripheral = peripheral.peripheral else {
            completion(.failure(UnexpectedError.failedToFindRuuviTag))
            return
        }
        let transport = McuMgrBleTransport(peripheral)
        transport.logDelegate = self
        let shell = ShellManager(transport: transport)
        shell.logDelegate = self
        self.transport = transport
        self.shell = shell
        shell.execute(command: command, arguments: arguments) { response, error in
            if let error {
                completion(.failure(error))
            } else if let error = response?.getError() {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    func stop() {
        if central?.isScanning == true { central?.stopScan() }
        central?.delegate = nil
        central = nil
        stateChanged = nil
        discovered = nil
        let transport = transport
        self.transport = nil
        shell = nil
        transport?.close()
    }
}

extension CoreBluetoothAirShellTransport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) { stateChanged?(central.state) }
    func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi: NSNumber
    ) {
        discovered?(.init(identifier: peripheral.identifier, peripheral: peripheral))
    }
}

extension CoreBluetoothAirShellTransport: McuMgrLogDelegate {
    func minLogLevel() -> McuMgrLogLevel { .debug }
    func log(_ msg: String, ofCategory category: McuMgrLogCategory, atLevel level: McuMgrLogLevel) {
        #if DEBUG || ALPHA
            print("[RuuviAirShellClient Log] - [\(category) \(level)] \(msg)")
        #endif
    }
}
