import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class MeasurementCoordinatorTests: XCTestCase {
    func testGraphTapDismissesTheRealSheetAndForwardsTheExactSensorAndVariant() async throws {
        let fixture = try await MeasurementCoordinatorFixture()
        defer { fixture.close() }
        fixture.coordinator.start()
        let sheet = try await fixture.sheet()
        XCTAssertEqual(sheet.sheetPresentationController?.prefersGrabberVisible, true)
        XCTAssertEqual(sheet.sheetPresentationController?.preferredCornerRadius, 16)
        XCTAssertTrue(sheet.presentationController?.delegate === fixture.coordinator)
        XCTAssertGreaterThan(sheet.preferredContentSize.height, 0)
        sheet.output?.didTapGraph()
        await waitForAppState("details graph navigation") { fixture.delegate.graphs.count == 1 }
        XCTAssertNil(fixture.base.view.presentedViewController)
        let selected = try XCTUnwrap(fixture.delegate.graphs.first)
        XCTAssertEqual(selected.0, fixture.measurements.snapshot.id)
        XCTAssertEqual(selected.1, .temperature)
        XCTAssertEqual(selected.2, fixture.variant)
        XCTAssertEqual(selected.3, fixture.measurements.sensor.id)
        XCTAssertTrue(selected.4 === fixture.coordinator)
        let reads = fixture.measurements.storage.latestCount
        fixture.measurements.snapshot.latestRawRecord = fixture.measurements.record(temperature: 24)
        await flushAppBindings()
        XCTAssertEqual(fixture.measurements.storage.latestCount, reads)
    }

    func testInteractiveDismissalReportsTheCoordinatorAndStopDetachesLiveReadings() async throws {
        let fixture = try await MeasurementCoordinatorFixture()
        defer { fixture.close() }
        fixture.coordinator.start()
        let sheet = try await fixture.sheet()
        let presentation = try XCTUnwrap(sheet.presentationController)
        await withCheckedContinuation { done in fixture.base.view.dismiss(animated: false) { done.resume() } }
        fixture.coordinator.presentationControllerDidDismiss(presentation)
        XCTAssertEqual(fixture.delegate.dismissed.count, 1)
        XCTAssertTrue(fixture.delegate.dismissed.first === fixture.coordinator)
        XCTAssertTrue(fixture.delegate.graphs.isEmpty)
        fixture.coordinator.stop()
        let reads = fixture.measurements.storage.latestCount
        fixture.measurements.snapshot.latestRawRecord = fixture.measurements.record(temperature: 29)
        await flushAppBindings()
        XCTAssertEqual(fixture.measurements.storage.latestCount, reads)
        fixture.coordinator.presentationControllerDidDismiss(presentation)
        XCTAssertEqual(fixture.delegate.dismissed.count, 1, "Stopped coordinators detach their delegate")
    }
}

@MainActor private final class MeasurementCoordinatorFixture {
    let base: CardsBaseScreenFixture
    let measurements = MeasurementFixture()
    let delegate = MeasurementCoordinatorDelegateSpy()
    let variant = MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit)
    let coordinator: MeasurementDetailsCoordinator
    init() async throws {
        base = try await CardsBaseScreenFixture()
        measurements.storage.records = [measurements.record()]
        let indicator = measurements.indicator(variant)
        measurements.snapshot.displayData.indicatorGrid = .init(indicators: [indicator])
        coordinator = MeasurementDetailsCoordinator(
            baseViewController: base.view, for: indicator,
            snapshot: measurements.snapshot, ruuviTagSensor: measurements.sensor, sensorSetting: nil, delegate: delegate
        )
        let measurements = measurements
        coordinator.makePresenter = { measurements.presenter() }
    }
    func sheet() async throws -> MeasurementDetailsViewController {
        await waitForAppState("details sheet presented") {
            self.base.view.presentedViewController is MeasurementDetailsViewController
                && self.base.view.presentedViewController?.isBeingPresented == false
                && self.measurements.storage.readCount == 1
        }
        return try XCTUnwrap(base.view.presentedViewController as? MeasurementDetailsViewController)
    }
    func close() { coordinator.stop(); base.close(); measurements.cleanup() }
}

private final class MeasurementCoordinatorDelegateSpy: MeasurementDetailsCoordinatorDelegate {
    var dismissed = [MeasurementDetailsCoordinator]()
    var graphs = [(String, MeasurementType, MeasurementDisplayVariant?, String, MeasurementDetailsCoordinator)]()
    func measurementDetailsCoordinatorDidDismiss(_ coordinator: MeasurementDetailsCoordinator) {
        dismissed.append(coordinator)
    }
    func measurementDetailsCoordinatorDidDismissWithGraphTap(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType, variant: MeasurementDisplayVariant?, ruuviTag: RuuviTagSensor,
        _ coordinator: MeasurementDetailsCoordinator
    ) {
        graphs.append((snapshot.id, measurement, variant, ruuviTag.id, coordinator))
    }
}
