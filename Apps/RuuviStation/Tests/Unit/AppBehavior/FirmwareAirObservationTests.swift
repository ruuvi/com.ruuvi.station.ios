import Combine
import Foundation
import RuuviOntology
import XCTest
@testable import station

@MainActor final class FirmwareAirObservationTests: XCTestCase {
    func testAirReappearanceMatchesEitherMacOrLocalIdentityAndStopsAfterSuccess() async {
        for matchMac in [true, false] {
            let fixture = FirmwareBluetoothFixture()
            defer { fixture.cleanup() }
            let interactor = fixture.interactor()
            var completions = 0
            let token = interactor.waitForAirDevice(ruuviTag: fixture.sensor, timeout: 1).sink(
                receiveCompletion: {
                    if case .failure(let error) = $0 { XCTFail("Unexpected \(error)") }
                }, receiveValue: { completions += 1 })
            await waitForAppState("Air advertisement scan") { fixture.scans.count == 1 }
            var packet = fixture.measurements.record()
            packet.luid = UUID().uuidString.luid
            packet.macId = "00:00:00:00:00:00".mac
            fixture.scans[0](packet)
            await flushAppBindings(); await flushAppBindings()
            XCTAssertEqual(completions, 0)
            if matchMac { packet.macId = fixture.sensor.macId } else { packet.luid = fixture.sensor.luid }
            fixture.scans[0](packet)
            await waitForAppState("Air device reappeared") { completions == 1 }
            XCTAssertEqual(fixture.cancelledScans, 1)
            fixture.scans[0](packet)
            await flushAppBindings()
            XCTAssertEqual(completions, 1)
            withExtendedLifetime(token) {}
        }
    }

    func testAirTimeoutFailsOnceAndReleasesItsScanner() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        var failures = [Error]()
        let token = interactor.waitForAirDevice(ruuviTag: fixture.sensor, timeout: 0.02).sink(
            receiveCompletion: {
                if case .failure(let error) = $0 { failures.append(error) }
            }, receiveValue: { XCTFail("Absent Air device succeeded") })
        await waitForAppState("Air timeout") { failures.count == 1 }
        XCTAssertEqual(failures[0] as? station.DFUError, .airDeviceTimeout)
        XCTAssertEqual(fixture.cancelledScans, 1)
        fixture.scans[0](fixture.measurements.record())
        await flushAppBindings()
        XCTAssertEqual(failures.count, 1)
        withExtendedLifetime(token) {}
    }

    func testCancellationBeforeTheRestartDelayPreventsScanningAndReleasesTheInteractor() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        var interactor: DFUInteractor? = fixture.interactor(delay: 0.04)
        weak var weakInteractor = interactor
        var token: AnyCancellable? = interactor!.waitForAirDevice(ruuviTag: fixture.sensor, timeout: 1).sink(
            receiveCompletion: { _ in XCTFail("Cancelled Air wait completed") },
            receiveValue: { XCTFail("Cancelled Air wait emitted") })
        token?.cancel(); token = nil; interactor = nil
        await waitForAppState("cancelled Air wait released") { weakInteractor == nil }
        XCTAssertTrue(fixture.scans.isEmpty)
    }

    func testAirWaitSubscriptionsHaveIndependentScannersAndCancellation() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor()
        let publisher = interactor.waitForAirDevice(ruuviTag: fixture.sensor, timeout: 1)
        XCTAssertTrue(fixture.scans.isEmpty)
        var received = 0
        let first = publisher.sink(
            receiveCompletion: { _ in XCTFail("Cancelled Air wait completed") },
            receiveValue: { XCTFail("Cancelled Air wait emitted") })
        let second = publisher.sink(receiveCompletion: { _ in }, receiveValue: { received += 1 })
        await waitForAppState("independent Air scans") { fixture.scans.count == 2 }
        first.cancel()
        await flushAppBindings()
        XCTAssertEqual(fixture.cancelledScans, 1)
        fixture.scans[0](fixture.measurements.record())
        fixture.scans[1](fixture.measurements.record())
        await waitForAppState("remaining Air wait completed") { received == 1 }
        XCTAssertEqual(fixture.cancelledScans, 2)
        withExtendedLifetime(second) {}
    }

    func testTagFirmwareDoesNotWaitForAirAdvertisements() async {
        let fixture = FirmwareBluetoothFixture()
        defer { fixture.cleanup() }
        let interactor = fixture.interactor(device: .ruuviTag)
        var received = 0
        let token = interactor.waitForAirDevice(ruuviTag: fixture.sensor, timeout: 1).sink(
            receiveCompletion: { _ in },
            receiveValue: { received += 1 })
        XCTAssertEqual(received, 1)
        XCTAssertTrue(fixture.scans.isEmpty)
        withExtendedLifetime(token) {}
    }
}
