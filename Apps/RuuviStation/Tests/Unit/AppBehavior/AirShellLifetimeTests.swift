import CoreBluetooth
import RuuviOntology
import XCTest
@testable import station

@MainActor final class AirShellLifetimeTests: XCTestCase {
    func testDuplicateAdvertisementsAndScanDeadlineCannotInterruptAnAcknowledgement() async throws {
        let transport = AirShellTransportSpy()
        let client = RuuviAirShellClient(makeTransport: { transport }, scanTimeout: 0.02)
        let uuid = UUID()
        let finished = expectation(description: "No scan failure after the sensor has been found")
        finished.isInverted = true
        var results = [Result<Void, Error>]()
        var checkingScanDeadline = true
        client.setLedBrightness(uuid: uuid.uuidString, level: .normal) {
            results.append($0)
            if checkingScanDeadline { finished.fulfill() }
        }
        await waitForAppState("lookup started") { transport.stateChanged != nil }
        transport.stateChanged?(.poweredOn)
        transport.discovered?(.init(identifier: uuid))
        transport.discovered?(.init(identifier: uuid))
        XCTAssertEqual(transport.commands.count, 1)
        await fulfillment(of: [finished], timeout: 0.08)
        checkingScanDeadline = false
        XCTAssertTrue(results.isEmpty)
        try XCTUnwrap(transport.commands.first).completion(.success(()))
        await waitForAppState("acknowledgement delivered") { results.count == 1 }
    }

    func testOldCallbacksCannotCompleteTheNextRequestAndCleanupCompletesOnlyOnce() async throws {
        let first = AirShellTransportSpy()
        let second = AirShellTransportSpy()
        let uuid = UUID()
        first.cached = .init(identifier: uuid)
        second.cached = .init(identifier: uuid)
        var starts = 0
        let client = RuuviAirShellClient(makeTransport: {
            starts += 1; return starts == 1 ? first : second
        })
        var firstResults = 0
        var secondResults = 0
        client.setLedBrightness(uuid: uuid.uuidString, level: .dim) { _ in firstResults += 1 }
        await waitForAppState("first lookup") { first.stateChanged != nil }
        first.stateChanged?(.poweredOn)
        let oldCommand = try XCTUnwrap(first.commands.first)
        first.stateChanged?(.poweredOff)
        await waitForAppState("first failed") { firstResults == 1 }
        client.setLedBrightness(uuid: uuid.uuidString, level: .bright) { _ in secondResults += 1 }
        await waitForAppState("second lookup") { second.stateChanged != nil }
        second.stateChanged?(.poweredOn)
        let newCommand = try XCTUnwrap(second.commands.first)
        oldCommand.completion(.success(()))
        first.stateChanged?(.poweredOff)
        first.discovered?(.init(identifier: uuid))
        await flushAppBindings()
        XCTAssertEqual(secondResults, 0)
        XCTAssertEqual(second.stops, 0)
        second.onStop = { newCommand.completion(.failure(NSError(domain: "Closing transport", code: 1))) }
        newCommand.completion(.success(()))
        await waitForAppState("second acknowledgement") { secondResults == 1 }
        XCTAssertEqual(firstResults, 1)
        XCTAssertEqual(secondResults, 1)
        XCTAssertEqual(second.stops, 1)
    }

    func testBackgroundCallbacksAlwaysExecuteTransportAndCompletionOnMain() async throws {
        let transport = AirShellTransportSpy()
        let client = RuuviAirShellClient(makeTransport: { transport })
        let uuid = UUID()
        var completedOnMain = false
        var completions = 0
        client.setLedBrightness(uuid: uuid.uuidString, level: .normal) { _ in
            completedOnMain = Thread.isMainThread
            completions += 1
        }
        await waitForAppState("transport started") { transport.stateChanged != nil }
        let state = try XCTUnwrap(transport.stateChanged)
        DispatchQueue.global().async { state(.poweredOn) }
        await waitForAppState("scan started on main") { transport.scans == 1 }
        let discovered = try XCTUnwrap(transport.discovered)
        DispatchQueue.global().async { discovered(.init(identifier: uuid)) }
        await waitForAppState("command started on main") { transport.commands.count == 1 }
        let command = try XCTUnwrap(transport.commands.first)
        DispatchQueue.global().async { command.completion(.success(())) }
        await waitForAppState("completion delivered on main") { completions == 1 }
        XCTAssertTrue(completedOnMain)
        XCTAssertTrue(transport.allOnMain)
        XCTAssertEqual(transport.stops, 1)
    }

    func testReleasingClientClosesOutstandingTransportAndDropsLateResult() async throws {
        let transport = AirShellTransportSpy()
        let uuid = UUID()
        transport.cached = .init(identifier: uuid)
        var client: RuuviAirShellClient? = RuuviAirShellClient(makeTransport: { transport })
        weak var released = client
        var completions = 0
        client?.setLedBrightness(uuid: uuid.uuidString, level: .off) { _ in completions += 1 }
        await waitForAppState("lookup started") { transport.stateChanged != nil }
        transport.stateChanged?(.poweredOn)
        let command = try XCTUnwrap(transport.commands.first)
        client = nil
        await flushAppBindings()
        XCTAssertNil(released)
        XCTAssertEqual(transport.stops, 1)
        command.completion(.success(()))
        await flushAppBindings()
        XCTAssertEqual(completions, 0)
    }
}
