import Foundation
import RuuviOntology
import RuuviReactor
import XCTest
@testable import station

@MainActor final class OffsetCorrectionLifecycleTests: XCTestCase {
    func testSlowStoredReadingCannotReplaceNewerLiveReadingOrNewCalibration() async {
        let fixture = OffsetCorrectionFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.measurements.storage.beforeLatest = { await withCheckedContinuation { release = $0 } }
        fixture.configure(.temperature)
        fixture.presenter?.viewDidLoad()
        await waitForAppState("suspended initial read") { release != nil }
        let live = fixture.measurements.record(date: Date().addingTimeInterval(100), temperature: 30)
        fixture.reactor.sendLatest(fixture.measurements.sensor, .insert(live.any))
        fixture.reactor.sendSettings(fixture.measurements.sensor, .insert(fixture.offsets(3)))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 30)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 33)
        release?.resume()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 30)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 33)
    }

    func testReconfigurationIgnoresOldReadAndOldObserverCallbacks() async {
        let fixture = OffsetCorrectionFixture()
        var release: CheckedContinuation<Void, Never>?
        fixture.measurements.storage.beforeLatest = { await withCheckedContinuation { release = $0 } }
        fixture.configure(.temperature)
        fixture.presenter?.viewDidLoad()
        await waitForAppState("suspended initial read") { release != nil }
        let staleRecordCallback = fixture.reactor.latest.values.first?.1
        let staleSettingsCallback = fixture.reactor.settings.values.first?.1
        fixture.measurements.storage.beforeLatest = nil
        fixture.measurements.storage.latestOverride = fixture.measurements.record(temperature: 25)
        fixture.configure(.temperature, offsets: fixture.offsets(4))
        await waitForAppState("new configuration loaded") { fixture.view.viewModel.originalValue.value == 25 }
        staleRecordCallback?(
            .update(fixture.measurements.record(date: Date().addingTimeInterval(100), temperature: 90).any))
        staleSettingsCallback?(.update(fixture.offsets(50)))
        release?.resume()
        await Task.yield()
        XCTAssertEqual(fixture.reactor.latest.count, 1)
        XCTAssertEqual(fixture.reactor.settings.count, 1)
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 25)
        XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 29)
    }

    func testOldSaveCompletionCannotChangeReconfiguredScreenOrShowStaleError() async {
        for fail in [false, true] {
            let fixture = OffsetCorrectionFixture()
            fixture.configure(.temperature)
            await waitForAppState("original reading") { fixture.view.viewModel.originalValue.value != nil }
            var release: CheckedContinuation<Void, Never>?
            fixture.service.beforeSave = { await withCheckedContinuation { release = $0 } }
            fixture.presenter?.viewDidSetCorrectValue(correctValue: 30)
            await waitForAppState("suspended save") { release != nil }
            fixture.configure(.pressure, offsets: fixture.offsets())
            await waitForAppState("new pressure screen") { fixture.view.viewModel.originalValue.value == 1000 }
            fixture.service.failure = fail ? .failedToParseNetworkResponse : nil
            release?.resume()
            await waitForAppState("old save completed") { fixture.service.completed == 1 }
            await flushAppBindings()
            XCTAssertEqual(fixture.view.viewModel.correctedValue.value, 1010)
            XCTAssertEqual(fixture.view.viewModel.offsetCorrectionValue.value, 10)
            XCTAssertTrue(fixture.errors.errors.isEmpty)
        }
    }

    func testDismissalReleasesPresenterWhileLoadingAndSavingAndRemovesObservers() async {
        for loading in [true, false] {
            let fixture = OffsetCorrectionFixture()
            var release: CheckedContinuation<Void, Never>?
            if loading {
                fixture.measurements.storage.beforeLatest = { await withCheckedContinuation { release = $0 } }
            }
            fixture.configure(.temperature)
            fixture.presenter?.viewDidLoad()
            if !loading {
                await waitForAppState("original reading") { fixture.view.viewModel.originalValue.value != nil }
                fixture.service.beforeSave = { await withCheckedContinuation { release = $0 } }
                fixture.presenter?.viewDidSetCorrectValue(correctValue: 30)
            }
            await waitForAppState("suspended operation") { release != nil }
            weak var presenter = fixture.presenter
            fixture.presenter = nil
            XCTAssertNil(presenter)
            XCTAssertTrue(fixture.reactor.latest.isEmpty)
            XCTAssertTrue(fixture.reactor.settings.isEmpty)
            let previousUnit = fixture.view.viewModel.temperatureUnit.value
            fixture.measurements.settings.temperatureUnit = .kelvin
            fixture.notifications.post(name: .TemperatureUnitDidChange, object: nil)
            XCTAssertEqual(fixture.view.viewModel.temperatureUnit.value, previousUnit)
            release?.resume()
            await Task.yield()
        }
    }

    func testFailedInitialReadStillAllowsLiveUpdatesAndUnitChanges() async {
        let fixture = OffsetCorrectionFixture()
        fixture.measurements.storage.failLatest = true
        fixture.configure(.temperature)
        fixture.presenter?.viewDidLoad()
        await Task.yield()
        fixture.reactor.sendLatest(fixture.measurements.sensor, .initial([nil, fixture.measurements.record().any]))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 20)
        fixture.measurements.settings.temperatureUnit = .fahrenheit
        fixture.measurements.settings.humidityUnit = .gm3
        fixture.measurements.settings.pressureUnit = .inchesOfMercury
        fixture.notifications.post(name: .TemperatureUnitDidChange, object: nil)
        fixture.notifications.post(name: .HumidityUnitDidChange, object: nil)
        fixture.notifications.post(name: .PressureUnitDidChange, object: nil)
        XCTAssertEqual(fixture.view.viewModel.temperatureUnit.value, .fahrenheit)
        XCTAssertEqual(fixture.view.viewModel.humidityUnit.value, .gm3)
        XCTAssertEqual(fixture.view.viewModel.pressureUnit.value, .inchesOfMercury)
        fixture.reactor.sendLatest(fixture.measurements.sensor, .update(nil))
        XCTAssertEqual(fixture.view.viewModel.originalValue.value, 20)
    }
}
