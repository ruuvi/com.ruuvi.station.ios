import Combine
import Foundation
import RuuviDFU
import RuuviOntology
import XCTest
@testable import station

@MainActor final class FirmwareBluetoothObservationTests: XCTestCase {
    func testAirBootloaderDiscoveryIgnoresOtherDevicesAndStopsOnceTheTargetIsFound() async throws {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        let publisher = interactor.listen(ruuviTag: fixture.sensor)
        XCTAssertTrue(fixture.radio.scans.isEmpty)
        var devices = [String]()
        let token = publisher.sink { devices.append($0.uuid) }
        await waitForAppState("DFU scan starts") { fixture.radio.scans.count == 1 }
        XCTAssertFalse(fixture.radio.scans[0].0)
        fixture.radio.scans[0].1(fixture.device(uuid: UUID().uuidString))
        await flushAppBindings()
        XCTAssertTrue(devices.isEmpty)
        fixture.radio.scans[0].1(fixture.device())
        await waitForAppState("target DFU device found") { devices.count == 1 }
        XCTAssertEqual(devices, [fixture.sensor.luid!.value])
        XCTAssertEqual(fixture.radio.scanCancellations, [0])
        fixture.radio.scans[0].1(fixture.device())
        await flushAppBindings()
        XCTAssertEqual(devices.count, 1)
        withExtendedLifetime(token) {}
    }

    func testLegacyBootloaderDiscoveryIncludesDfuServicesAndAcceptsItsNewIdentity() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        fixture.sensor.version = 5
        let interactor = fixture.interactor(device: .ruuviTag)
        var devices = [String]()
        let token = interactor.listen(ruuviTag: fixture.sensor).sink { devices.append($0.uuid) }
        await waitForAppState("legacy DFU scan") { fixture.radio.scans.count == 1 }
        XCTAssertTrue(fixture.radio.scans[0].0)
        let bootloader = fixture.device(uuid: UUID().uuidString)
        fixture.radio.scans[0].1(bootloader)
        await waitForAppState("legacy bootloader found") { devices.count == 1 }
        XCTAssertEqual(devices, [bootloader.uuid])
        XCTAssertEqual(fixture.radio.scanCancellations, [0])
        withExtendedLifetime(token) {}
    }

    func testLostObservationMatchesTheDeviceAndCancellationOnlyStopsItsOwnSubscription() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        let publisher = interactor.observeLost(uuid: fixture.sensor.luid!.value)
        var received = [String]()
        let first = publisher.sink { _ in XCTFail("Cancelled lost observation emitted") }
        let second = publisher.sink { received.append($0) }
        await waitForAppState("independent lost observations") { fixture.radio.lost.count == 2 }
        first.cancel()
        await flushAppBindings()
        XCTAssertEqual(fixture.radio.lostCancellations, [0])
        fixture.radio.lost[1](fixture.device(uuid: UUID().uuidString))
        await flushAppBindings()
        XCTAssertTrue(received.isEmpty)
        fixture.radio.lost[0](fixture.device())
        fixture.radio.lost[1](fixture.device())
        await waitForAppState("target disappeared") { received.count == 1 }
        XCTAssertEqual(received, [fixture.sensor.luid!.value])
        XCTAssertEqual(fixture.radio.lostCancellations, [0, 1])
        withExtendedLifetime(second) {}
    }

    func testCancellingFirmwareDiscoveryReleasesTheInteractorAndItsObserver() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        var interactor: DFUInteractor? = fixture.interactor()
        weak var weakInteractor = interactor
        var token: AnyCancellable? = interactor!.listen(ruuviTag: fixture.sensor).sink { _ in }
        await waitForAppState("scan before close") { fixture.radio.scans.count == 1 }
        interactor = nil
        token?.cancel(); token = nil
        await waitForAppState("firmware interactor released") { weakInteractor == nil }
        XCTAssertEqual(fixture.radio.scanCancellations, [0])
    }
}
