import Combine
import Foundation
import XCTest
@testable import RuuviFirmware

@MainActor final class ModuleFirmwareObservationTests: XCTestCase {
    func testRevisionReadsAreLazySanitizeDisplayVersionsAndPropagateBluetoothErrors() async {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor()
        let publisher = interactor.serveCurrentRelease(uuid: "first")
        XCTAssertTrue(fixture.revision.isEmpty)
        var versions = [String]()
        var failures = [Error]()
        let first = publisher.sink(
            receiveCompletion: { if case .failure(let error) = $0 { failures.append(error) } },
            receiveValue: { versions.append($0.version) })
        let second = interactor.serveCurrentRelease(uuid: "second").sink(
            receiveCompletion: { if case .failure(let error) = $0 { failures.append(error) } },
            receiveValue: { _ in XCTFail("Failed revision emitted") })
        await waitForFirmwareState("two independent revision reads") { fixture.revision.count == 2 }
        XCTAssertEqual(fixture.revision.map(\.0), ["first", "second"])
        fixture.revision[0].1(.success("3.31.1+0"))
        fixture.revision[1].1(.failure(NSError(domain: "FirmwareTest", code: 17)))
        await waitForFirmwareState("revision callbacks delivered") { versions.count == 1 && failures.count == 1 }
        XCTAssertEqual(versions, ["3.31.1"])
        XCTAssertEqual((failures.first as NSError?)?.code, 17)
        withExtendedLifetime((first, second)) {}
    }

    func testRevisionTimeoutAndCancellationIgnoreLateResults() async {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor(timeout: 0.02)
        var failures = 0
        let first = interactor.serveCurrentRelease(uuid: "timeout").sink(
            receiveCompletion: { if case .failure = $0 { failures += 1 } },
            receiveValue: { _ in XCTFail("Timed out revision emitted") })
        let cancelled = interactor.serveCurrentRelease(uuid: "cancelled").sink(
            receiveCompletion: { _ in XCTFail("Cancelled revision completed") },
            receiveValue: { _ in XCTFail("Cancelled revision emitted") })
        await waitForFirmwareState("both revision reads started") { fixture.revision.count == 2 }
        cancelled.cancel()
        await waitForFirmwareState("revision deadline expired") { failures == 1 }
        fixture.revision.forEach { $0.1(.success("9.0.0")) }
        await drainFirmwareCallbacks(); await drainFirmwareCallbacks()
        XCTAssertEqual(failures, 1)
        withExtendedLifetime(first) {}
    }

    func testDfuDiscoveryAndLostObservationStopAfterTheMatchingResult() async {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor()
        var found = [String]()
        var lost = [String]()
        let discovery = interactor.listen().sink { found.append($0) }
        let loss = interactor.observeLost(uuid: "target").sink { lost.append($0) }
        await waitForFirmwareState("DFU observations started") {
            fixture.radio.scans.count == 1 && fixture.radio.lost.count == 1
        }
        fixture.radio.lost[0](fixture.device(uuid: "other"))
        await drainFirmwareCallbacks()
        XCTAssertTrue(lost.isEmpty)
        fixture.radio.scans[0](fixture.device(uuid: "target"))
        fixture.radio.lost[0](fixture.device(uuid: "target"))
        await waitForFirmwareState("DFU target observed") { found.count == 1 && lost.count == 1 }
        XCTAssertEqual(found, ["target"])
        XCTAssertEqual(lost, ["target"])
        XCTAssertEqual(fixture.radio.scanStops, 1)
        XCTAssertEqual(fixture.radio.lostStops, 1)
        fixture.radio.scans[0](fixture.device(uuid: "later"))
        await drainFirmwareCallbacks()
        XCTAssertEqual(found, ["target"])
        withExtendedLifetime((discovery, loss)) {}
    }

    func testClosingDiscoveryCancelsNativeObservationAndReleasesTheInteractor() async {
        let fixture = ModuleFirmwareFixture()
        var interactor: FirmwareInteractor? = fixture.interactor()
        weak var weakInteractor = interactor
        var token: AnyCancellable? = interactor!.listen().sink { _ in XCTFail("Closed screen received a device") }
        await waitForFirmwareState("DFU discovery active") { fixture.radio.scans.count == 1 }
        token?.cancel(); token = nil; interactor = nil
        await waitForFirmwareState("DFU interactor released") { weakInteractor == nil }
        XCTAssertEqual(fixture.radio.scanStops, 1)
    }

    func testSuccessfulFlashUsesTheSelectedArchiveAndPublishesCompletion() {
        let fixture = ModuleFirmwareFixture()
        let interactor = fixture.interactor()
        let app = URL(fileURLWithPath: "/app.zip")
        let full = URL(fileURLWithPath: "/full.zip")
        var completed = false
        let token = interactor.flash(
            uuid: "target", latestRelease: .init(version: "3.31.1", assets: []),
            currentRelease: .init(version: "3.30.0"), appUrl: app, fullUrl: full
        ).sink(
            receiveCompletion: { _ in }, receiveValue: { if case .done = $0 { completed = true } })
        XCTAssertEqual(fixture.radio.files, [app])
        XCTAssertEqual(fixture.radio.flashed, ["target"])
        XCTAssertTrue(completed)
        withExtendedLifetime(token) {}
    }
}
