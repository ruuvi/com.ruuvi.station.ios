import RuuviOntology
import XCTest
@testable import station

@MainActor final class CardSettingsNotesTests: XCTestCase {
    func testSavingNotesNormalizesEmptyValuesAndLimitsUnicodeCharacters() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        for input in [nil, "", "Room note", String(repeating: "🧑🏽‍🔬", count: 1001)] {
            fixture.presenter.viewDidTapNotes()
            var result: Result<Void, Error>?
            fixture.router.saveNotes?(input) { result = $0 }
            await waitForAppState("notes persisted") { result != nil }
            guard case .success = result else { return XCTFail("Expected successful notes update") }
            let expected = input.flatMap { $0.isEmpty ? nil : String($0.prefix(1000)) }
            XCTAssertEqual(fixture.services.data.properties.descriptions.last?.0, fixture.sensor.id)
            XCTAssertEqual(fixture.services.data.properties.descriptions.last?.1, expected)
            XCTAssertEqual(fixture.view.notes.last?.0, expected)
            XCTAssertEqual(fixture.view.notes.last?.1, true)
        }
        XCTAssertEqual(fixture.activity.dismissals.count, 4)
    }

    func testLocalSaveFailureReturnsTheErrorAndPreservesNotes() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.services.data.properties.failure = .failedToParseNetworkResponse
        fixture.presenter.viewDidTapNotes()
        var result: Result<Void, Error>?
        fixture.router.saveNotes?("New") { result = $0 }
        await waitForAppState("notes failure") { result != nil }
        guard case .failure = result else { return XCTFail("Expected local storage failure") }
        XCTAssertEqual(fixture.errors.errors.count, 1)
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testCloudFailureKeepsTheSavedLocalNoteAndReportsDeferredCloudSaving() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.services.data.properties.failure = .ruuviCloud(.notAuthorized)
        fixture.services.data.pool.sensorSettings[fixture.sensor.id] = SensorSettingsStruct(
            luid: fixture.sensor.luid, macId: fixture.sensor.macId, temperatureOffset: nil,
            humidityOffset: nil, pressureOffset: nil, description: "Saved locally")
        fixture.presenter.viewDidTapNotes()
        var result: Result<Void, Error>?
        fixture.router.saveNotes?("Saved locally") { result = $0 }
        await waitForAppState("local notes restored") { result != nil }
        guard case .success = result else { return XCTFail("Local notes must remain usable after cloud failure") }
        XCTAssertEqual(fixture.view.notes.last?.0, "Saved locally")
        XCTAssertEqual(fixture.services.data.pool.settingsReads, [fixture.sensor.id])
        XCTAssertTrue(fixture.errors.errors.isEmpty)
        XCTAssertEqual(fixture.activity.updates.count, 1)
    }

    func testMissingSensorCompletesWithFailureWithoutStartingAWrite() {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        fixture.configure(withSensor: false)
        fixture.presenter.viewDidTapNotes()
        var result: Result<Void, Error>?
        fixture.router.saveNotes?("Draft") { result = $0 }
        guard case .failure = result else { return XCTFail("Missing sensor must fail") }
        XCTAssertTrue(fixture.services.data.properties.descriptions.isEmpty)
        XCTAssertTrue(fixture.activity.shown.isEmpty)
    }

    func testClosingDuringAFailedSaveStillCompletesTheCallbackAndDismissesLoading() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.services.data.properties.beforeDescription = { await withCheckedContinuation { release = $0 } }
        fixture.services.data.properties.failure = .failedToParseNetworkResponse
        fixture.presenter.viewDidTapNotes()
        var result: Result<Void, Error>?
        fixture.router.saveNotes?("Draft") { result = $0 }
        await waitForAppState("notes request pending") { release != nil }
        weak var presenter = fixture.presenter
        fixture.presenter = nil
        XCTAssertNil(presenter)
        release?.resume(); release = nil
        await waitForAppState("closed notes save completed") { result != nil }
        guard case .failure = result else { return XCTFail("The callback must receive the failure") }
        XCTAssertEqual(fixture.activity.dismissals.count, 1)
    }

    func testLateNotesSaveCannotReplaceAnotherSensorsNotes() async {
        let fixture = CardSettingsFixture()
        defer { fixture.cleanup() }
        var release: CheckedContinuation<Void, Never>?
        fixture.services.data.properties.beforeDescription = { await withCheckedContinuation { release = $0 } }
        fixture.presenter.viewDidTapNotes()
        var completed = false
        fixture.router.saveNotes?("First sensor") { _ in completed = true }
        await waitForAppState("notes request pending") { release != nil }
        var second = fixture.measurements.sensor
        second.macId = "112233AABBCC".mac
        second.luid = "second-notes-sensor".luid
        fixture.sensor = second.any
        fixture.calibration = SensorSettingsStruct(
            luid: second.luid, macId: second.macId, temperatureOffset: nil,
            humidityOffset: nil, pressureOffset: nil, description: "Second sensor")
        fixture.configure()
        release?.resume(); release = nil
        await waitForAppState("first notes completed") { completed }
        fixture.presenter.viewDidTapNotes()
        XCTAssertEqual(fixture.router.noteValues.last!, "Second sensor")
        XCTAssertEqual(fixture.services.data.properties.descriptions.first?.0, fixture.measurements.sensor.id)
    }
}
