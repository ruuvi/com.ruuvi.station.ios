import CoreBluetooth
import Foundation
import RuuviOntology
@testable import station

final class AirShellTransportSpy: RuuviAirShellTransport {
    struct Command {
        let id: UUID
        let command: String
        let arguments: [String]
        let completion: (Result<Void, Error>) -> Void
    }
    var stateChanged: ((CBManagerState) -> Void)?
    var discovered: ((RuuviAirShellPeripheral) -> Void)?
    var cached: RuuviAirShellPeripheral?
    var retrieved = [UUID]()
    var commands = [Command]()
    var scans = 0
    var scanStops = 0
    var stops = 0
    var allOnMain = true
    var onStop: (() -> Void)?
    func start(
        stateChanged: @escaping (CBManagerState) -> Void, discovered: @escaping (RuuviAirShellPeripheral) -> Void
    ) {
        allOnMain = allOnMain && Thread.isMainThread
        self.stateChanged = stateChanged
        self.discovered = discovered
    }
    func retrieve(_ identifier: UUID) -> RuuviAirShellPeripheral? {
        retrieved.append(identifier)
        return cached
    }
    func scan() { allOnMain = allOnMain && Thread.isMainThread; scans += 1 }
    func stopScan() { allOnMain = allOnMain && Thread.isMainThread; scanStops += 1 }
    func execute(
        on peripheral: RuuviAirShellPeripheral, command: String, arguments: [String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        allOnMain = allOnMain && Thread.isMainThread
        commands.append(
            .init(id: peripheral.identifier, command: command, arguments: arguments, completion: completion))
    }
    func stop() {
        allOnMain = allOnMain && Thread.isMainThread
        stops += 1
        if stops == 1 { onStop?() }
    }
}
