import Foundation
import RuuviCloud
import RuuviOntology
import RuuviService
import XCTest
#if SWIFT_PACKAGE
    import RuuviServiceOwnership
#endif

@MainActor final class OwnershipServiceTests: XCTestCase {
    func testClaimPersistsOwnershipAndUploadsCalibrationAlertsAndCustomBackground() async throws {
        let fixture = try OwnershipServiceFixture()
        defer { fixture.close() }
        let data = fixture.data
        let sensor = data.sensor.with(isCloudSensor: false).with(isClaimed: false).withoutOwner()
        _ = try await data.pool.create(sensor)
        _ = try await data.pool.updateOffsetCorrection(type: .temperature, with: 2, of: sensor)
        _ = try await data.pool.updateOffsetCorrection(type: .humidity, with: 0.1, of: sensor)
        _ = try await data.pool.updateOffsetCorrection(type: .pressure, with: 3, of: sensor)
        data.alerts.register(type: .temperature(lower: 5, upper: 30), ruuviTag: sensor)
        fixture.images.cached[sensor.macId!.value] = fixture.images.image
        var uploads = 0
        data.cloud.onUpload = { request in
            uploads += 1
            XCTAssertEqual(request.macId.value, sensor.macId?.value)
            XCTAssertGreaterThan(request.data.count, 100)
            return URL(string: "https://example.invalid/background.jpg")!
        }
        let claimed = try await fixture.service.claim(sensor: sensor)
        XCTAssertTrue(claimed.isCloud && claimed.isClaimed && claimed.isOwner)
        XCTAssertEqual(claimed.owner, fixture.user.email)
        let stored = try await data.storage.readOne(sensor.id)
        XCTAssertEqual(stored.owner, fixture.user.email)
        XCTAssertEqual(data.cloud.ownershipRequests.first?.argument, sensor.name)
        XCTAssertEqual(data.cloud.offsetWrites.first?.temperature, 2)
        XCTAssertEqual(data.cloud.offsetWrites.first?.humidity, 10)
        XCTAssertEqual(data.cloud.offsetWrites.first?.pressure, 300)
        XCTAssertEqual(uploads, 1)
        for _ in 0..<200 where data.cloud.alerts.isEmpty { try await Task.sleep(nanoseconds: 5_000_000) }
        XCTAssertTrue(data.cloud.alerts.contains { $0.type == .temperature && $0.enabled })
    }

    func testContestingATruncatedAirAddressResolvesAndCachesItsCanonicalAddress() async throws {
        let fixture = try OwnershipServiceFixture()
        defer { fixture.close() }
        let data = fixture.data
        var sensor = data.sensor
        sensor.version = 6
        let shortMac = String(data.sensor.macId!.value.suffix(8))
        let canonicalMac = "AA:BB:CC:" + shortMac
        sensor.macId = shortMac.mac
        defer {
            data.ids.removeFullMac(for: sensor.macId!)
            UserDefaults.standard.removeObject(forKey: shortMac)
        }
        _ = try await data.pool.create(sensor)
        data.cloud.ownerResponse = ("previous@example.com", canonicalMac)
        let claimed = try await fixture.service.contest(sensor: sensor, secret: "nfc-secret")
        XCTAssertEqual(claimed.owner, fixture.user.email)
        XCTAssertEqual(data.cloud.ownershipRequests.map(\.operation), ["check", "contest"])
        XCTAssertEqual(data.cloud.ownershipRequests.last?.mac, canonicalMac.lowercased())
        XCTAssertEqual(data.cloud.ownershipRequests.last?.argument, "nfc-secret")
        XCTAssertEqual(data.ids.fullMac(for: sensor.macId!)?.value, canonicalMac.lowercased())
        _ = try await fixture.service.claim(sensor: sensor)
        XCTAssertEqual(data.cloud.ownershipRequests.map(\.operation), ["check", "contest", "claim"])
    }

    func testUnclaimClearsCloudOwnershipAndSharingAndForwardsTheHistoryChoice() async throws {
        let fixture = try OwnershipServiceFixture()
        defer { fixture.close() }
        let data = fixture.data
        let sensor = data.sensor.with(canShare: true).with(sharedTo: ["reader@example.com"])
            .with(sharedToPending: ["pending@example.com"])
        _ = try await data.pool.create(sensor)
        let result = try await fixture.service.unclaim(sensor: sensor, removeCloudHistory: true)
        XCTAssertFalse(result.isClaimed)
        XCTAssertFalse(result.isCloud)
        XCTAssertFalse(result.canShare)
        XCTAssertNil(result.owner)
        XCTAssertTrue(result.sharedTo.isEmpty)
        XCTAssertTrue(result.sharedToPending.isEmpty)
        XCTAssertEqual(data.cloud.ownershipRequests.last?.removeHistory, true)
        let stored = try await data.storage.readOne(sensor.id)
        XCTAssertFalse(stored.isCloud)
        XCTAssertNil(stored.owner)
    }

    func testAddingASensorStoresItsFirstReadingAsAnAdvertisementAndRefreshesTheTimestamp() async throws {
        let fixture = try OwnershipServiceFixture()
        defer { fixture.close() }
        let data = fixture.data
        let sensor = try await fixture.service.add(sensor: data.sensor, record: data.record())
        XCTAssertNotNil(sensor.lastUpdated)
        let latest = try await data.storage.readLatest(sensor)
        XCTAssertEqual(latest?.source, .advertisement)
        XCTAssertEqual(latest?.temperature?.value, 20)
        let records = try await data.storage.readAll(sensor.id)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.source, .advertisement)
    }

    func testMissingIdentityOrAccountAndCloudFailuresDoNotChangeLocalOwnership() async throws {
        let fixture = try OwnershipServiceFixture()
        defer { fixture.close() }
        let data = fixture.data
        var sensor = data.sensor
        _ = try await data.pool.create(sensor)
        fixture.user.email = nil
        do { _ = try await fixture.service.claim(sensor: sensor); XCTFail("Missing account succeeded") } catch {
            guard case .ruuviCloud(.notAuthorized) = error else { return XCTFail("Unexpected \(error)") }
        }
        sensor.macId = nil
        do {
            _ = try await fixture.service.contest(sensor: sensor, secret: "secret"); XCTFail("Missing MAC succeeded")
        } catch {
            guard case .macIdIsNil = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertTrue(data.cloud.ownershipRequests.isEmpty)
        fixture.user.email = "new-owner@example.com"
        data.cloud.ownershipFailure = .api(.api(.erForbidden))
        do { _ = try await fixture.service.claim(sensor: data.sensor); XCTFail("Cloud failure ignored") } catch {
            guard case .ruuviCloud(.api(.api(.erForbidden))) = error else { return XCTFail("Unexpected \(error)") }
        }
        let stored = try await data.storage.readOne(data.sensor.id)
        XCTAssertEqual(stored.owner, data.sensor.owner)
    }
}
