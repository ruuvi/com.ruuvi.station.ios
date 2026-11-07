import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
@testable import station

@MainActor final class ConnectionContractFixture {
    let transport = ConnectionTransportSpy()
    let persistence = CoordinatorConnectionsSpy()
    let sync = AppSyncStateSpy()
    let center = NotificationCenter()
    let delegate = ConnectionDelegateSpy()
    var permission = true
    lazy var service: RuuviTagConnectionService = {
        let service = RuuviTagConnectionService(
            foreground: BTKit.foreground, background: BTKit.background,
            connectionPersistence: persistence, localSyncState: sync, transport: transport,
            notificationCenter: center, permissionGranted: { [unowned self] in permission })
        service.delegate = delegate
        return service
    }()
    func snapshot(cloud: Bool = false, bluetooth: Bool = true) -> RuuviTagCardSnapshot {
        .create(
            id: UUID().uuidString, name: "Office", luid: bluetooth ? UUID().uuidString.luid : nil,
            mac: UUID().uuidString.mac, serviceUUID: "FEAA", isCloud: cloud,
            isOwner: true, isConnectable: bluetooth, version: 5)
    }
}

final class ConnectionTransportSpy: RuuviConnectionTransport {
    private let lock = NSLock()
    var state: BTScannerState = .poweredOn
    private var connected = Set<String>()
    var callbacks = [(BTScannerState) -> Void]()
    var cancellations = 0
    func setConnected(_ value: Bool, uuid: String) {
        lock.withLock {
            if value { connected.insert(uuid) } else { connected.remove(uuid) }
        }
    }
    func isConnected(uuid: String) -> Bool { lock.withLock { connected.contains(uuid) } }
    func observeState(_ receive: @escaping (BTScannerState) -> Void) -> () -> Void {
        callbacks.append(receive)
        return { [weak self] in self?.cancellations += 1 }
    }
}

final class ConnectionDelegateSpy: RuuviTagConnectionServiceDelegate {
    var snapshots = [RuuviTagCardSnapshot]()
    var states = [(Bool, Bool)]()
    var errors = [Error]()
    var onMain = true
    func connectionService(_ service: RuuviTagConnectionService, didUpdateSnapshot snapshot: RuuviTagCardSnapshot) {
        onMain = onMain && Thread.isMainThread
        snapshots.append(snapshot)
    }
    func connectionService(
        _ service: RuuviTagConnectionService, bluetoothStateChanged isEnabled: Bool, userDeclined: Bool
    ) {
        onMain = onMain && Thread.isMainThread
        states.append((isEnabled, userDeclined))
    }
    func connectionService(_ service: RuuviTagConnectionService, didEncounterError error: Error) {
        errors.append(error)
    }
}
