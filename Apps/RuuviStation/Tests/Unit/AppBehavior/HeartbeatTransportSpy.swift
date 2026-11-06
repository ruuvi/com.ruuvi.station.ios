import BTKit
@testable import RuuviDaemon

final class HeartbeatTransportSpy: RuuviHeartbeatTransport {
    struct Connection {
        let uuid: String
        let connected: (BTConnectResult) -> Void
        let heartbeat: (RuuviTag) -> Void
        let disconnected: (BTDisconnectResult) -> Void
    }
    var connectedIDs = Set<String>()
    var connections = [Connection]()
    var disconnects = [(String, (BTDisconnectResult) -> Void)]()
    var scans = [(String, (RuuviTag) -> Void)]()
    var cancelledConnections = [String]()
    var cancelledDisconnects = [String]()
    var cancelledScans = [String]()
    func isConnected(uuid: String) -> Bool { connectedIDs.contains(uuid) }
    func connect(
        uuid: String, connected: @escaping (BTConnectResult) -> Void,
        heartbeat: @escaping (RuuviTag) -> Void, disconnected: @escaping (BTDisconnectResult) -> Void
    ) -> () -> Void {
        connections.append(.init(uuid: uuid, connected: connected, heartbeat: heartbeat, disconnected: disconnected))
        return { [weak self] in self?.cancelledConnections.append(uuid) }
    }
    func disconnect(uuid: String, result: @escaping (BTDisconnectResult) -> Void) -> () -> Void {
        disconnects.append((uuid, result))
        return { [weak self] in self?.cancelledDisconnects.append(uuid) }
    }
    func observe(serviceUUID: String, receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        scans.append((serviceUUID, receive))
        return { [weak self] in self?.cancelledScans.append(serviceUUID) }
    }
}
