import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardSettingsLEDTests: XCTestCase {
    func testBrightnessRouteUsesSavedChoiceAndPersistsOnlyAnAcknowledgedChange() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.setLedBrightnessSelection(.dim, for: fixture.sensor.macId)
        var writes = [(String, RuuviLedBrightnessLevel)]()
        fixture.presenter.writeLedBrightness = { id, value, done in
            writes.append((id, value)); done(.success(()))
        }
        fixture.presenter.viewDidTapLedBrightness()
        XCTAssertEqual(fixture.router.selectedLED, .dim)
        XCTAssertEqual(fixture.router.ledFirmware, "1.3.0")
        XCTAssertEqual(fixture.router.ledSnapshotID, fixture.snapshot.id)
        var succeeded = false
        fixture.router.selectLED?(.bright) { result in if case .success = result { succeeded = true } }
        XCTAssertTrue(succeeded)
        XCTAssertEqual(writes.first?.0, fixture.sensor.luid?.value)
        XCTAssertEqual(writes.first?.1, .bright)
        XCTAssertEqual(fixture.measurements.settings.ledBrightnessSelection(for: fixture.sensor.macId), .bright)
        XCTAssertEqual(fixture.view.brightness.last, .bright)
        fixture.router.updateFirmware?()
        XCTAssertEqual(fixture.router.paths.last?.0, "firmware")
    }

    func testFailedBrightnessWriteRestoresTheSavedAndDisplayedSelection() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.measurements.settings.setLedBrightnessSelection(.normal, for: fixture.sensor.macId)
        fixture.presenter.writeLedBrightness = { _, _, done in done(.failure(NSError(domain: "LEDTests", code: 1))) }
        fixture.presenter.viewDidTapLedBrightness()
        var failed = false
        fixture.router.selectLED?(.off) { result in if case .failure = result { failed = true } }
        XCTAssertTrue(failed)
        XCTAssertEqual(fixture.measurements.settings.ledBrightnessSelection(for: fixture.sensor.macId), .normal)
        XCTAssertEqual(fixture.view.brightness.last, .normal)
    }

    func testMissingSensorOrBluetoothIdentifierCompletesWithFailure() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        for missingSensor in [false, true] {
            var sensor = fixture.measurements.sensor
            sensor.luid = nil
            fixture.sensor = sensor.any
            fixture.configure(withSensor: !missingSensor)
            fixture.presenter.viewDidTapLedBrightness()
            var failed = false
            fixture.router.selectLED?(.dim) { result in if case .failure = result { failed = true } }
            XCTAssertTrue(failed)
        }
    }
}
