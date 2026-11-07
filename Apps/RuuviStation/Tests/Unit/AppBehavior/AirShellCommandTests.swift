import CoreBluetooth
import RuuviOntology
import XCTest
@testable import station

@MainActor final class AirShellCommandTests: XCTestCase {
    func testEachBrightnessUsesTheOriginalShellCommandAndCachedPeripheralWithoutScanning() async throws {
        for level: RuuviLedBrightnessLevel in [.off, .dim, .normal, .bright] {
            let transport = AirShellTransportSpy()
            let uuid = UUID()
            transport.cached = .init(identifier: uuid)
            let client = RuuviAirShellClient(makeTransport: { transport })
            var results = [Result<Void, Error>]()
            client.setLedBrightness(uuid: uuid.uuidString, level: level) { results.append($0) }
            await waitForAppState("command started") { transport.stateChanged != nil }
            transport.stateChanged?(.unknown)
            transport.stateChanged?(.resetting)
            XCTAssertTrue(transport.commands.isEmpty)
            transport.stateChanged?(.poweredOn)
            transport.stateChanged?(.poweredOn)
            let command = try XCTUnwrap(transport.commands.first)
            XCTAssertEqual(transport.retrieved, [uuid])
            XCTAssertEqual(command.id, uuid)
            XCTAssertEqual(command.command, "ruuvi")
            XCTAssertEqual(command.arguments, ["led_brightness", level.shellArgument])
            XCTAssertEqual(transport.commands.count, 1)
            XCTAssertEqual(transport.scans, 0)
            XCTAssertTrue(results.isEmpty)
            command.completion(.success(()))
            await waitForAppState("brightness acknowledged") { results.count == 1 }
            if case .failure(let error) = results[0] { XCTFail("Unexpected failure: \(error)") }
            XCTAssertEqual(transport.stops, 1)
            XCTAssertTrue(transport.allOnMain)
        }
    }

    func testInvalidIdentityBusyClientAndUnavailableBluetoothPreserveTheirErrors() async throws {
        let transport = AirShellTransportSpy()
        let client = RuuviAirShellClient(makeTransport: { transport })
        var errors = [Error]()
        let receive: (Result<Void, Error>) -> Void = { if case .failure(let error) = $0 { errors.append(error) } }
        client.setLedBrightness(uuid: "invalid", level: .dim, completion: receive)
        await waitForAppState("invalid identity rejected") { errors.count == 1 }
        XCTAssertEqual(errors[0] as? UnexpectedError, .viewModelUUIDIsNil)
        XCTAssertNil(transport.stateChanged)
        for state: CBManagerState in [.unsupported, .unauthorized, .poweredOff] {
            let previous = errors.count
            client.setLedBrightness(uuid: UUID().uuidString, level: .bright, completion: receive)
            await flushAppBindings()
            client.setLedBrightness(uuid: UUID().uuidString, level: .off, completion: receive)
            await waitForAppState("overlapping command rejected") { errors.count == previous + 1 }
            XCTAssertEqual(errors.last as? UnexpectedError, .callerDeinitedDuringOperation)
            transport.stateChanged?(state)
            await waitForAppState("unavailable Bluetooth rejected") { errors.count == previous + 2 }
            XCTAssertEqual(errors.last as? UnexpectedError, .failedToFindRuuviTag)
        }
        XCTAssertEqual(transport.stops, 3)
        XCTAssertTrue(transport.commands.isEmpty)
    }

    func testScanFindsOnlyTheRequestedSensorAndForwardsCommandFailures() async throws {
        let transport = AirShellTransportSpy()
        let client = RuuviAirShellClient(makeTransport: { transport })
        let uuid = UUID()
        var result: Result<Void, Error>?
        client.setLedBrightness(uuid: uuid.uuidString, level: .normal) { result = $0 }
        await waitForAppState("lookup started") { transport.stateChanged != nil }
        transport.stateChanged?(.poweredOn)
        XCTAssertEqual(transport.scans, 1)
        transport.discovered?(.init(identifier: UUID()))
        XCTAssertTrue(transport.commands.isEmpty)
        XCTAssertNil(result)
        transport.discovered?(.init(identifier: uuid))
        XCTAssertEqual(transport.scanStops, 1)
        let command = try XCTUnwrap(transport.commands.first)
        let failure = NSError(domain: "Device command", code: 7)
        command.completion(.failure(failure))
        await waitForAppState("device error delivered") { result != nil }
        if case .failure(let error) = result {
            XCTAssertEqual(error as NSError, failure)
        } else {
            XCTFail("The device failure must not be treated as an acknowledged brightness change")
        }
        XCTAssertEqual(transport.stops, 1)
    }

    func testUnsuccessfulScanTimesOutAndASecondRequestCanRetry() async {
        let transport = AirShellTransportSpy()
        let client = RuuviAirShellClient(makeTransport: { transport }, scanTimeout: 0.02)
        var failures = 0
        for _ in 0..<2 {
            let previous = failures
            client.setLedBrightness(uuid: UUID().uuidString, level: .dim) { result in
                if case .failure(let error) = result {
                    XCTAssertEqual(error as? UnexpectedError, .failedToFindRuuviTag)
                    failures += 1
                }
            }
            await flushAppBindings()
            transport.stateChanged?(.poweredOn)
            await waitForAppState("scan timeout") { failures == previous + 1 }
        }
        XCTAssertEqual(transport.scans, 2)
        XCTAssertEqual(transport.scanStops, 2)
        XCTAssertEqual(transport.stops, 2)
    }
}
