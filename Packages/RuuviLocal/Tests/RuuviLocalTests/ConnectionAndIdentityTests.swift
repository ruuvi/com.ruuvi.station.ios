import Foundation
import RuuviLocal
#if SWIFT_PACKAGE
    @testable import RuuviLocalUserDefaults
#else
    @testable import RuuviLocal
#endif
import RuuviOntology
import XCTest

final class ConnectionAndIdentityTests: XCTestCase {
    func testRepeatedConnectionChangesAreIdempotentAndPreserveOtherSensors() throws {
        try withDefaults { defaults in
            let notifications = NotificationCenter()
            let connections = RuuviLocalConnectionsUserDefaults(defaults: defaults, notifications: notifications)
            let first = UUID().uuidString.luid
            let second = UUID().uuidString.luid
            var started: [String] = []
            var stopped: [String] = []
            let start = notifications.addObserver(
                forName: .ConnectionPersistenceDidStartToKeepConnection, object: nil, queue: nil
            ) { event in
                let uuid = event.userInfo?[CPDidStartToKeepConnectionKey.uuid] as? String
                started.append(uuid ?? "")
                XCTAssertTrue(connections.keepConnection(to: (uuid ?? "").luid))
            }
            let stop = notifications.addObserver(
                forName: .ConnectionPersistenceDidStopToKeepConnection, object: nil, queue: nil
            ) { event in
                let uuid = event.userInfo?[CPDidStopToKeepConnectionKey.uuid] as? String
                stopped.append(uuid ?? "")
                XCTAssertFalse(connections.keepConnection(to: (uuid ?? "").luid))
            }
            defer { notifications.removeObserver(start); notifications.removeObserver(stop) }
            XCTAssertTrue(connections.keepConnectionUUIDs.isEmpty)
            XCTAssertFalse(connections.keepConnection(to: first))
            connections.setKeepConnection(false, for: first)
            connections.setKeepConnection(true, for: first)
            connections.setKeepConnection(true, for: second)
            connections.setKeepConnection(true, for: first)
            XCTAssertEqual(connections.keepConnectionUUIDs.map(\.value), [first.value, second.value])
            XCTAssertEqual(started, [first.value, second.value])
            XCTAssertEqual(RuuviLocalConnectionsUserDefaults(defaults: defaults).keepConnectionUUIDs.count, 2)
            connections.setKeepConnection(false, for: first)
            connections.setKeepConnection(false, for: first)
            XCTAssertTrue(connections.keepConnection(to: second))
            XCTAssertEqual(stopped, [first.value])
            connections.unpairAllConnection()
            XCTAssertTrue(connections.keepConnectionUUIDs.isEmpty)
            XCTAssertEqual(stopped, [first.value, second.value])
            connections.unpairAllConnection()
            XCTAssertEqual(stopped.count, 2)
        }
    }

    func testUnpairAllPersistsEmptyStateBeforeNotifyingAndToleratesMissingOrCorruptedStorage() throws {
        try withDefaults { defaults in
            let key = "ConnectionPersistenceUserDefaults.keepConnection.array"
            let notifications = NotificationCenter()
            let connections = RuuviLocalConnectionsUserDefaults(defaults: defaults, notifications: notifications)
            let first = UUID().uuidString.luid
            let second = UUID().uuidString.luid
            connections.unpairAllConnection()
            defaults.set(42, forKey: key)
            XCTAssertTrue(connections.keepConnectionUUIDs.isEmpty)
            XCTAssertFalse(connections.keepConnection(to: first))
            connections.setKeepConnection(true, for: first)
            connections.setKeepConnection(true, for: second)
            var stopped: [String] = []
            let token = notifications.addObserver(
                forName: .ConnectionPersistenceDidStopToKeepConnection, object: nil, queue: nil
            ) {
                XCTAssertTrue(connections.keepConnectionUUIDs.isEmpty)
                stopped.append($0.userInfo?[CPDidStopToKeepConnectionKey.uuid] as? String ?? "")
            }
            defer { notifications.removeObserver(token) }
            connections.unpairAllConnection()
            XCTAssertEqual(stopped, [first.value, second.value])
        }
    }

    func testIdentifierMappingsSurviveReloadWithoutConfusingNormalExtendedAndFullIdentifiers() throws {
        try withDefaults { defaults in
            let ids = RuuviLocalIDsUserDefaults(defaults: defaults)
            let luid = UUID().uuidString.luid
            let extended = UUID().uuidString.luid
            let mac = "AA:BB:CC:DD:EE:01".mac
            let full = "AA:BB:CC:DD:EE:02".mac
            XCTAssertNil(ids.mac(for: luid))
            XCTAssertNil(ids.luid(for: mac))
            XCTAssertNil(ids.extendedLuid(for: mac))
            XCTAssertNil(ids.fullMac(for: mac))
            XCTAssertNil(ids.originalMac(for: full))
            ids.set(mac: mac, for: luid)
            ids.set(luid: luid, for: mac)
            ids.set(extendedLuid: extended, for: mac)
            ids.set(fullMac: full, for: mac)
            let restored = RuuviLocalIDsUserDefaults(defaults: defaults)
            XCTAssertEqual(restored.mac(for: luid)?.value, mac.value)
            XCTAssertEqual(restored.luid(for: mac)?.value, luid.value)
            XCTAssertEqual(restored.extendedLuid(for: mac)?.value, extended.value)
            XCTAssertEqual(restored.fullMac(for: mac)?.value, full.value)
            XCTAssertEqual(restored.originalMac(for: full)?.value, mac.value)
            restored.removeFullMac(for: mac)
            restored.removeFullMac(for: mac)
            XCTAssertNil(restored.fullMac(for: mac))
            XCTAssertNil(restored.originalMac(for: full))
            XCTAssertEqual(restored.luid(for: mac)?.value, luid.value)
        }
    }

    func testReplacingAndTransferringFullMACMappingsRemovesStaleReverseLookups() throws {
        try withDefaults { defaults in
            let ids = RuuviLocalIDsUserDefaults(defaults: defaults)
            let first = "AA:BB:CC:DD:EE:01".mac
            let second = "AA:BB:CC:DD:EE:02".mac
            let old = "AA:BB:CC:DD:EE:03".mac
            let new = "AA:BB:CC:DD:EE:04".mac
            ids.set(fullMac: old, for: first)
            ids.set(fullMac: new, for: first)
            XCTAssertNil(ids.originalMac(for: old))
            XCTAssertEqual(ids.originalMac(for: new)?.value, first.value)
            ids.set(fullMac: new, for: second)
            XCTAssertNil(ids.fullMac(for: first))
            XCTAssertEqual(ids.originalMac(for: new)?.value, second.value)
            ids.removeFullMac(for: first)
            XCTAssertEqual(ids.originalMac(for: new)?.value, second.value)
            ids.set(fullMac: new, for: second)
            XCTAssertEqual(ids.fullMac(for: second)?.value, new.value)
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let name = "ruuvi-local-identifiers-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }
}
