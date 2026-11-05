import RuuviDaemon
import RuuviLocal
import RuuviOntology
import RuuviReactor
import UIKit
import XCTest
@testable import station

@MainActor final class SensorDataServiceTests: XCTestCase {
    func testInitialSnapshotsExposeSensorMetadataAndSortNaturallyUnlessManualOrderIsSaved() async throws {
        for manual in [false, true] {
            let fixture = SensorDataFixture()
            defer { fixture.cleanup() }
            let first = fixture.sensor("Room 10", version: 5)
            var second = fixture.sensor("Room 2", cloud: true)
            second.owner = "OWNER@EXAMPLE.COM"
            second.ownersPlan = "Pro"
            second.sharedTo = ["shared@example.com"]
            second.sharedToPending = ["invited@example.com"]
            second.firmwareVersion = "3.4.5"
            if manual {
                fixture.measurements.settings.dashboardSensorOrder = [first.macId!.value, second.macId!.value]
            }
            await fixture.start([first, second])
            XCTAssertEqual(
                fixture.service.getAllSnapshots().map(\.id), manual ? [first.id, second.id] : [second.id, first.id])
            XCTAssertEqual(Set(fixture.service.getAllSensors().map(\.id)), [first.id, second.id])
            XCTAssertEqual(fixture.service.getSensor(for: first.id)?.name, "Room 10")
            XCTAssertNil(fixture.service.getSensor(for: "missing"))
            XCTAssertNil(fixture.service.getSnapshot(for: "missing"))
            let local = try XCTUnwrap(fixture.service.getSnapshot(for: first.id))
            XCTAssertTrue(local.capabilities.showKeepConnection)
            XCTAssertTrue(local.capabilities.showBatteryStatus)
            XCTAssertFalse(local.capabilities.isCloudAlertsAvailable)
            let cloud = try XCTUnwrap(fixture.service.getSnapshot(for: second.id))
            XCTAssertEqual(cloud.ownership.ownerName, "owner@example.com")
            XCTAssertEqual(cloud.ownership.sharedTo, second.sharedTo)
            XCTAssertEqual(cloud.ownership.sharedToPending, second.sharedToPending)
            XCTAssertTrue(cloud.ownership.isOwnersPlanProPlus)
            XCTAssertTrue(cloud.capabilities.isCloudConnectionAlertsAvailable)
            XCTAssertFalse(cloud.capabilities.showKeepConnection)
            XCTAssertEqual(cloud.displayData.firmwareVersion, "3.4.5")
            XCTAssertEqual(fixture.delegate.animations.first, false)
            XCTAssertEqual(fixture.reactor.latest.count, 2)
            XCTAssertEqual(fixture.reactor.settings.count, 2)
        }
    }

    func testInsertDeleteAndRenameMaintainAutomaticAndManualSensorOrder() async throws {
        for manual in [false, true] {
            let fixture = SensorDataFixture()
            defer { fixture.cleanup() }
            var first = fixture.sensor("Zulu")
            let second = fixture.sensor("Office")
            if manual { fixture.measurements.settings.dashboardSensorOrder = [first.macId!.value] }
            await fixture.start([first])
            var advertisements = 0
            var heartbeats = 0
            let firstToken = fixture.notifications.addObserver(
                forName: .RuuviTagAdvertisementDaemonShouldRestart,
                object: nil, queue: nil
            ) { _ in advertisements += 1 }
            let secondToken = fixture.notifications.addObserver(
                forName: .RuuviTagHeartBeatDaemonShouldRestart,
                object: nil, queue: nil
            ) { _ in heartbeats += 1 }
            defer {
                fixture.notifications.removeObserver(firstToken); fixture.notifications.removeObserver(secondToken)
            }
            fixture.send(.insert(second.any))
            XCTAssertEqual(fixture.service.getAllSnapshots().map(\.id), [second.id, first.id])
            XCTAssertEqual(fixture.delegate.inserted, [second.id])
            XCTAssertEqual(fixture.delegate.orders.last, [second.macId!.value, first.macId!.value])
            XCTAssertEqual(fixture.reactor.latest.count, 2)
            first.name = "Attic"
            fixture.send(.update(first.any))
            await waitForAppState("renamed sensor") {
                fixture.service.getSnapshot(for: first.id)?.displayData.name == "Attic"
            }
            XCTAssertEqual(
                fixture.service.getAllSnapshots().map(\.id), manual ? [second.id, first.id] : [first.id, second.id])
            fixture.service.reorderSnapshots(with: [second.macId!.value, first.macId!.value])
            XCTAssertEqual(fixture.service.getAllSnapshots().map(\.id), [second.id, first.id])
            fixture.send(.delete(second.any))
            XCTAssertNil(fixture.service.getSnapshot(for: second.id))
            XCTAssertNil(fixture.service.getSensor(for: second.id))
            XCTAssertEqual(fixture.reactor.latest.count, 1)
            XCTAssertEqual(fixture.reactor.settings.count, 1)
            XCTAssertEqual(advertisements, 2)
            XCTAssertEqual(heartbeats, 2)
        }
    }

    func testEveryLiveRecordEventUpdatesTheCorrectSnapshotAndUnknownSensorsAreIgnored() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        for (index, source) in ["initial", "insert", "update", "direct"].enumerated() {
            let record = fixture.measurements.record(
                date: Date().addingTimeInterval(Double(index)), temperature: Double(20 + index))
            switch source {
            case "initial": fixture.reactor.sendLatest(sensor, .initial([nil, record.any]))
            case "insert": fixture.reactor.sendLatest(sensor, .insert(record.any))
            case "update": fixture.reactor.sendLatest(sensor, .update(record.any))
            default: fixture.service.updateSnapshot(for: sensor.id, with: record)
            }
            await waitForAppState(source + " reading") { snapshot.lastUpdated == record.date }
            XCTAssertEqual(snapshot.latestRawRecord?.temperature?.value, Double(20 + index))
            XCTAssertFalse(snapshot.displayData.hasNoData)
            XCTAssertFalse(snapshot.displayData.indicatorGrid?.indicators.isEmpty ?? true)
        }
        let latestDate = snapshot.lastUpdated
        fixture.reactor.sendLatest(sensor, .update(nil))
        fixture.service.updateSnapshot(for: "missing", with: fixture.measurements.record())
        await flushAppBindings()
        XCTAssertEqual(snapshot.lastUpdated, latestDate)
    }

    func testCalibrationAndVisibilitySettingsRefreshTheExistingReadingAndDeletionRestoresDefaults() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let sensor = fixture.sensor()
        fixture.measurements.storage.latestOverride = fixture.measurements.record()
        await fixture.start([sensor])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: sensor.id))
        let code = try XCTUnwrap(
            RuuviTagDataService.measurementCode(for: .init(type: .temperature, temperatureUnit: .fahrenheit)))
        let calibration = fixture.calibration(sensor, codes: [code], useDefault: false)
        fixture.reactor.sendSettings(sensor, .initial([calibration]))
        await waitForAppState("calibrated display") { snapshot.latestRawRecord?.temperatureOffset == 2 }
        XCTAssertEqual(fixture.service.getSensorSettings(for: sensor.id)?.temperatureOffset, 2)
        XCTAssertEqual(fixture.service.getSensorSettings().count, 1)
        XCTAssertEqual(snapshot.latestRawRecord?.temperature?.value, 22)
        XCTAssertEqual(snapshot.displayData.measurementVisibility?.usesDefaultOrder, false)
        XCTAssertEqual(snapshot.displayData.measurementVisibility?.visibleVariants.map(\.type), [.temperature])
        let changed = fixture.calibration(sensor, temperature: 5)
        fixture.reactor.sendSettings(sensor, .update(changed))
        await waitForAppState("changed calibration") { snapshot.latestRawRecord?.temperatureOffset == 5 }
        XCTAssertEqual(snapshot.latestRawRecord?.temperature?.value, 25)
        XCTAssertEqual(fixture.service.getSensorSettings().count, 1)
        fixture.reactor.sendSettings(sensor, .delete(changed))
        await waitForAppState("removed calibration") { snapshot.latestRawRecord?.temperatureOffset == 0 }
        XCTAssertEqual(snapshot.latestRawRecord?.temperature?.value, 20)
        XCTAssertNil(fixture.service.getSensorSettings(for: sensor.id))
        XCTAssertTrue(fixture.service.getSensorSettings().isEmpty)
        XCTAssertEqual(snapshot.displayData.measurementVisibility?.usesDefaultOrder, true)
        XCTAssertGreaterThan(snapshot.displayData.measurementVisibility?.visibleVariants.count ?? 0, 1)
    }

    func testBackgroundReloadsOnlyTheAffectedSensorAndFailuresPreserveItsCurrentImage() async throws {
        let fixture = SensorDataFixture()
        defer { fixture.cleanup() }
        let first = fixture.sensor("A")
        let second = fixture.sensor("B")
        let initial = fixture.image(.red)
        fixture.properties.images[first.id] = initial
        fixture.properties.images[second.id] = initial
        await fixture.start([first, second])
        let snapshot = try XCTUnwrap(fixture.service.getSnapshot(for: first.id))
        await waitForAppState("initial backgrounds") {
            snapshot.displayData.background != nil
                && fixture.service.getSnapshot(for: second.id)?.displayData.background != nil
        }
        for identity in ["luid", "mac"] {
            let count = fixture.properties.imageReads.filter { $0 == second.id }.count
            let image = fixture.image(identity == "luid" ? .green : .blue)
            fixture.properties.images[first.id] = image
            let info: [AnyHashable: Any] =
                identity == "luid"
                ? [BPDidChangeBackgroundKey.luid: first.luid!]
                : [BPDidChangeBackgroundKey.macId: first.macId!]
            fixture.notifications.post(name: .BackgroundPersistenceDidChangeBackground, object: nil, userInfo: info)
            await waitForAppState("changed background") { snapshot.displayData.background === image }
            XCTAssertEqual(fixture.properties.imageReads.filter { $0 == second.id }.count, count)
        }
        let image = snapshot.displayData.background
        fixture.properties.failure = .failedToGetJpegRepresentation
        let count = fixture.properties.imageReads.count
        fixture.service.loadBackgroundsForCurrentSnapshots()
        await waitForAppState("failed background reload") { fixture.properties.imageReads.count >= count + 2 }
        XCTAssertTrue(snapshot.displayData.background === image)
        fixture.notifications.post(name: .BackgroundPersistenceDidChangeBackground, object: nil)
        fixture.notifications.post(name: .BackgroundPersistenceDidChangeBackground, object: nil, userInfo: [:])
    }
}
