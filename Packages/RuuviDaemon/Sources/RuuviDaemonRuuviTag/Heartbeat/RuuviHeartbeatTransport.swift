import BTKit
import Foundation

/// Bluetooth boundaries used by the heartbeat daemon. Cancellation ends only this observation.
public protocol RuuviHeartbeatTransport: AnyObject {
    func isConnected(uuid: String) -> Bool
    func connect(
        uuid: String, connected: @escaping (BTConnectResult) -> Void,
        heartbeat: @escaping (RuuviTag) -> Void, disconnected: @escaping (BTDisconnectResult) -> Void
    ) -> () -> Void
    func disconnect(uuid: String, result: @escaping (BTDisconnectResult) -> Void) -> () -> Void
    func observe(serviceUUID: String, receive: @escaping (RuuviTag) -> Void) -> () -> Void
}

final class BTKitHeartbeatTransport: NSObject, RuuviHeartbeatTransport {
    private let background: BTBackground
    init(background: BTBackground) { self.background = background }
    func isConnected(uuid: String) -> Bool { background.isConnected(uuid: uuid) }
    func connect(
        uuid: String, connected: @escaping (BTConnectResult) -> Void,
        heartbeat: @escaping (RuuviTag) -> Void, disconnected: @escaping (BTDisconnectResult) -> Void
    ) -> () -> Void {
        let token = background.connect(
            for: self, uuid: uuid, options: [.callbackQueue(.dispatch(.main))],
            connected: { _, result in connected(result) },
            heartbeat: { _, device in
                if let tag = device.ruuvi?.tag { heartbeat(tag) }
            }, disconnected: { _, result in disconnected(result) })
        return { token?.invalidate() }
    }
    func disconnect(uuid: String, result: @escaping (BTDisconnectResult) -> Void) -> () -> Void {
        let token = background.disconnect(
            for: self, uuid: uuid, options: [.callbackQueue(.dispatch(.main))],
            result: { _, value in result(value) })
        return { token?.invalidate() }
    }
    func observe(serviceUUID: String, receive: @escaping (RuuviTag) -> Void) -> () -> Void {
        let token = background.observe(self, uuid: serviceUUID, options: [.callbackQueue(.dispatch(.main))]) {
            _, device in
            if let tag = device.ruuvi?.tag { receive(tag) }
        }
        return { token.invalidate() }
    }
}
