import XCTest
@testable import station

@MainActor final class ForceClaimBluetoothTests: XCTestCase {
    func testSuccessfulSecretReadCancelsItsTimeoutAndClaimsTheSensor() async {
        let fixture = ForceClaimFixture()
        fixture.presenter.gattTimeoutSeconds = 0.05
        var requests = [String]()
        fixture.presenter.readGattSecret = { id, _, completion in
            requests.append(id)
            completion(.success("bluetooth-secret"))
        }
        fixture.presenter.viewDidTapUseBluetooth()
        await waitForAppState("Bluetooth claim") { fixture.router.dismissals == 1 }
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(requests, [fixture.measurements.sensor.luid!.value])
        XCTAssertEqual(fixture.service.contests.first?.1, "bluetooth-secret")
        XCTAssertEqual(fixture.view.timeouts, 0)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testReadFailureEndsLoadingWithoutALaterTimeoutDialog() async {
        let fixture = ForceClaimFixture()
        fixture.presenter.gattTimeoutSeconds = 0.05
        fixture.presenter.readGattSecret = { _, _, completion in
            completion(.failure(NSError(domain: "ForceClaimTests", code: 1)))
        }
        fixture.presenter.viewDidTapUseBluetooth()
        await waitForAppState("Bluetooth failure") { fixture.errors.errors.count == 1 }
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(fixture.view.timeouts, 0)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
        XCTAssertTrue(fixture.service.contests.isEmpty)
    }

    func testDuplicateReadsCoalesceAndLateSuccessAfterTimeoutCannotClaim() async {
        let fixture = ForceClaimFixture()
        fixture.presenter.gattTimeoutSeconds = 0.05
        var completions = [(Result<String, Error>) -> Void]()
        fixture.presenter.readGattSecret = { _, _, completion in completions.append(completion) }
        fixture.presenter.viewDidTapUseBluetooth()
        fixture.presenter.viewDidTapUseBluetooth()
        XCTAssertEqual(completions.count, 1)
        await waitForAppState("Bluetooth timeout") { fixture.view.timeouts > 0 }
        completions.forEach { $0(.success("too-late-secret")) }
        await flushAppBindings(); await flushAppBindings()
        XCTAssertTrue(fixture.service.contests.isEmpty)
        XCTAssertEqual(fixture.router.dismissals, 0)
        XCTAssertEqual(fixture.view.timeouts, 1)
    }

    func testSensorWithoutBluetoothIdentifierNeverStartsAReadOrTimeout() async {
        let fixture = ForceClaimFixture()
        var sensor = fixture.measurements.sensor
        sensor.luid = nil
        fixture.presenter.configure(ruuviTag: sensor)
        fixture.presenter.gattTimeoutSeconds = 0.05
        var requests = 0
        fixture.presenter.readGattSecret = { _, _, _ in requests += 1 }
        fixture.presenter.viewDidTapUseBluetooth()
        try? await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(fixture.view.timeouts, 0)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }
}
