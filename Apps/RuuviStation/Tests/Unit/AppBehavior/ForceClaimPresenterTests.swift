import CoreNFC
import RuuviOntology
import XCTest
@testable import station

@MainActor final class ForceClaimPresenterTests: XCTestCase {
    func testAvailabilityDeviceTypeAndNavigationActions() {
        let fixture = ForceClaimFixture()
        fixture.measurements.settings.hideNFCForSensorContest = false
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.view.hiddenNFC, 0)
        fixture.measurements.settings.hideNFCForSensorContest = true
        fixture.presenter.viewDidLoad()
        XCTAssertEqual(fixture.view.hiddenNFC, 1)
        for version in [225, 6, 5, 3] {
            var sensor = fixture.measurements.sensor
            sensor.version = version
            fixture.presenter.configure(ruuviTag: sensor)
            fixture.presenter.viewWillAppear()
            XCTAssertEqual(fixture.view.deviceType, version == 225 || version == 6 ? .ruuviAir : .ruuviTag)
        }
        fixture.presenter.viewDidTapUseNFC()
        fixture.presenter.viewDidDismiss()
        XCTAssertEqual(fixture.view.starts, 1)
        XCTAssertEqual(fixture.router.dismissals, 1)
    }

    func testMatchingNFCScanTrimsNullsAndWhitespaceAndClaimsOnlyTheConfiguredSensor() async {
        let fixture = ForceClaimFixture()
        fixture.scan(secret: "  test-secret  ")
        await waitForAppState("NFC claim finished") { fixture.activity.dismissals.count == 1 }
        XCTAssertEqual(fixture.view.stops, 1)
        XCTAssertEqual(fixture.service.contests.first?.0.id, fixture.measurements.sensor.id)
        XCTAssertEqual(fixture.service.contests.first?.1, "test-secret")
        XCTAssertEqual(fixture.router.dismissals, 1)
    }

    func testWrongSensorAndMalformedPayloadsDoNotAttemptOwnershipChanges() async {
        let fixture = ForceClaimFixture()
        fixture.scan(mac: "WRONG-SENSOR")
        XCTAssertEqual(fixture.view.wrongScans, 1)
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.message(["unrecognized: value"], prefix: 1)])
        fixture.presenter.viewDidReceiveNFCMessages(messages: [fixture.message(["no separator", "a: b: c"])])
        fixture.presenter.viewDidReceiveNFCMessages(messages: [])
        await flushAppBindings()
        XCTAssertTrue(fixture.service.contests.isEmpty)
        XCTAssertEqual(fixture.router.dismissals, 0)
    }

    func testASecretFromAPreviousScanCannotBeReusedByANewIncompleteScan() async {
        let fixture = ForceClaimFixture()
        fixture.scan(secret: "old-secret", mac: "WRONG-SENSOR")
        fixture.presenter.viewDidReceiveNFCMessages(messages: [
            fixture.message([
                "adMAC: \(fixture.measurements.sensor.macId!.value)"
            ])
        ])
        await flushAppBindings()
        XCTAssertTrue(fixture.service.contests.isEmpty)
        XCTAssertEqual(fixture.router.dismissals, 0)
    }

    func testClaimFailureKeepsTheScreenAndReportsTheError() async {
        let fixture = ForceClaimFixture()
        fixture.service.shareFailure = .failedToParseNetworkResponse
        fixture.scan()
        await waitForAppState("NFC error") { fixture.errors.errors.count == 1 }
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
        XCTAssertEqual(fixture.router.dismissals, 0)
    }

    func testDuplicateScansCoalesceAndClosingDoesNotLeaveAnActivityIndicator() async {
        let fixture = ForceClaimFixture()
        var releases = [CheckedContinuation<Void, Never>]()
        fixture.service.beforeContest = { await withCheckedContinuation { releases.append($0) } }
        fixture.scan()
        await waitForAppState("claim pending") { !releases.isEmpty }
        fixture.scan()
        await flushAppBindings()
        XCTAssertEqual(fixture.service.contests.count, 1)
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        releases.forEach { $0.resume() }
        await waitForAppState("claim spinner dismissed") { fixture.activity.dismissals.count == releases.count }
        XCTAssertEqual(fixture.router.dismissals, 0)
    }
}
