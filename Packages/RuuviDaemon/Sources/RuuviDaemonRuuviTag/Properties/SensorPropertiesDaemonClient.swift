#if SWIFT_PACKAGE
    import RuuviDaemon
#endif
import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor

struct SensorPropertiesAdvertisement {
    let luid: String
    let mac: String?
    let version: Int
    let serviceUUID: String?
    let isConnectable: Bool
}

struct SensorPropertiesDaemonClient {
    var observeSensors: (@escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void) -> () -> Void
    var scan: (@escaping (SensorPropertiesAdvertisement) -> Void) -> () -> Void
    var macForLuid: (String) -> String?
    var readSensor: @MainActor (String) async throws(RuuviPersistenceError) -> RuuviTagSensor
    var updateSensor: @MainActor (RuuviTagSensor) async throws(RuuviPoolError) -> Bool
    var report: (RuuviDaemonError) -> Void

    static func live(
        pool: RuuviPool, reactor: RuuviReactor, foreground: BTForeground,
        identifiers: RuuviLocalIDs, persistence: RuuviPersistence
    ) -> Self {
        Self(
            observeSensors: { callback in
                let token = reactor.observe(callback)
                return { token.invalidate() }
            },
            scan: { callback in
                let owner = NSObject()
                let token = foreground.scan(owner) { _, device in
                    guard let tag = device.ruuvi?.tag else { return }
                    callback(
                        .init(
                            luid: device.uuid, mac: tag.mac, version: tag.version,
                            serviceUUID: device.serviceUUID, isConnectable: device.isConnectable))
                }
                return { withExtendedLifetime(owner) { token.invalidate() } }
            },
            macForLuid: { identifiers.mac(for: $0.luid)?.value },
            readSensor: { mac async throws(RuuviPersistenceError) in try await persistence.readOne(mac) },
            updateSensor: { sensor async throws(RuuviPoolError) in try await pool.update(sensor) },
            report: {
                NotificationCenter.default.post(
                    name: .RuuviTagPropertiesDaemonDidFail, object: nil,
                    userInfo: [RuuviTagPropertiesDaemonDidFailKey.error: $0])
            })
    }
}
