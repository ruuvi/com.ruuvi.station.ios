import Foundation
import RuuviOntology
import XCTest
#if SWIFT_PACKAGE
    @testable import RuuviDaemonRuuviTag
#else
    @testable import RuuviDaemon
#endif

extension SensorPropertiesLifecycleTests {
    func testShortenedAirMACCanDiscoverACloudSensorWithoutLosingItsFullAddress() async {
        for advertisedMAC in ["DD:EE:FF", "ddeeff", "C5:DD:EE:FF", "aa:bb:cc:dd:ee:ff"] {
            let fixture = SensorPropertiesFixture()
            fixture.stored.luid = nil
            fixture.stored.isCloudSensor = true
            let worker = fixture.makeWorker()
            defer { worker.stop() }
            worker.start()
            fixture.observations[0](.initial([fixture.stored.any]))
            fixture.scans[0](fixture.advertisement(mac: advertisedMAC))
            await eventually { fixture.finishedUpdates == 1 }
            XCTAssertEqual(fixture.updates.first?.macId?.value, fixture.mac)
            XCTAssertEqual(fixture.updates.first?.luid?.value, fixture.luid)
        }
    }

    func testChangedUUIDRepairsAStaleStoredMappingAndUsesTheSavedIdentityForLookup() async {
        let fixture = SensorPropertiesFixture()
        let replacement = UUID().uuidString
        fixture.luids[fixture.mac] = replacement
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any]))
        fixture.scans[0](fixture.advertisement(luid: replacement, mac: "DD:EE:FF"))
        await eventually { fixture.finishedUpdates == 1 }
        XCTAssertEqual(fixture.reads, [fixture.mac])
        XCTAssertEqual(fixture.updates.first?.luid?.value, replacement)
        XCTAssertEqual(fixture.updates.first?.macId?.value, fixture.mac)
    }

    func testAmbiguousShortAddressesDoNotRebindTheWrongSensor() async {
        let fixture = SensorPropertiesFixture()
        var second = fixture.stored
        second.macId = "11:22:33:DD:EE:FF".mac
        second.luid = UUID().uuidString.luid
        let worker = fixture.makeWorker()
        defer { worker.stop() }
        worker.start()
        fixture.observations[0](.initial([fixture.stored.any, second.any]))
        fixture.scans[0](fixture.advertisement(luid: "new", mac: "DD:EE:FF"))
        fixture.scans[0](fixture.advertisement(luid: "new", mac: "00:00:00:DD:EE:FF"))
        await settle()
        XCTAssertTrue(fixture.updates.isEmpty)
        XCTAssertTrue(fixture.reads.isEmpty)
        fixture.scans[0](fixture.advertisement(luid: "new"))
        await eventually { fixture.finishedUpdates == 1 }
        XCTAssertEqual(fixture.reads, [fixture.mac])
    }
}
