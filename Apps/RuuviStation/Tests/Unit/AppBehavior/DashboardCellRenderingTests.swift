import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class DashboardCellRenderingTests: XCTestCase {
    func testImageAndSimpleCardsRefreshProminentReadingsAndDoNotRetainThePreviousSensorOnReuse() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let cell = DashboardCell(frame: CGRect(x: 0, y: 0, width: 390, height: 260))
        let snapshot = fixture.snapshot
        snapshot.displayData.hasNoData = false
        snapshot.displayData.name = "Office air"
        for kind: DashboardType in [.image, .simple, .image] {
            cell.configure(with: snapshot, dashboardType: kind)
            for (value, quality) in [("85/100", MeasurementQualityState.good(85)), ("unavailable", .undefined(0))] {
                snapshot.displayData.indicatorGrid = .init(indicators: [
                    indicator(.aqi, value, quality: quality), indicator(.co2, "650"), indicator(.pm25, "2.5"),
                ])
                await flushAppBindings()
                cell.setNeedsLayout(); cell.layoutIfNeeded()
                XCTAssertTrue(labels(cell).contains("Office air"))
                XCTAssertTrue(labels(cell).contains("650"))
                if kind == .image {
                    XCTAssertTrue(labels(cell).contains(value == "85/100" ? "85" : RuuviLocalization.na))
                    let progress = try XCTUnwrap(
                        cell.allDescendants.compactMap { $0 as? DashboardLinearProgressView }.first)
                    XCTAssertFalse(progress.superview?.isHidden ?? true)
                }
            }
            snapshot.displayData.indicatorGrid = .init(indicators: [indicator(.temperature, "21.2")])
            await flushAppBindings()
            XCTAssertTrue(labels(cell).contains("21.2"))
            snapshot.displayData.indicatorGrid = .init(indicators: [])
            await flushAppBindings()
            XCTAssertFalse(labels(cell).contains("21.2"))
        }
        cell.prepareForReuse()
        snapshot.displayData.name = "This sensor has been removed"
        await flushAppBindings()
        XCTAssertFalse(labels(cell).contains("This sensor has been removed"))
        let next = MeasurementFixture()
        defer { next.cleanup() }
        next.snapshot.displayData.name = "Bedroom"
        cell.configure(with: next.snapshot, dashboardType: .simple)
        await flushAppBindings()
        XCTAssertTrue(labels(cell).contains("Bedroom"))
        cell.prepareForReuse()
    }

    func testAlertAvailabilityControlsTheBellAndSourceChangesStayVisible() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let cell = DashboardCell(frame: CGRect(x: 0, y: 0, width: 390, height: 260))
        defer { cell.prepareForReuse() }
        let output = DashboardCellOutputSpy()
        cell.delegate = output
        let snapshot = fixture.snapshot
        snapshot.metadata.isAlertAvailable = true
        cell.configure(with: snapshot, dashboardType: .image)
        for source: RuuviTagSensorRecordSource in [
            .unknown, .advertisement, .bgAdvertisement, .heartbeat, .log, .ruuviNetwork,
        ] {
            snapshot.displayData.source = source
            await flushAppBindings()
            cell.layoutIfNeeded()
            XCTAssertTrue(cell.allDescendants.compactMap { $0 as? UIImageView }.contains { $0.image != nil })
        }
        let button = try XCTUnwrap(
            cell.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.actions(forTarget: cell, forControlEvent: .touchUpInside)?.contains("alertButtonTapped") == true
            })
        snapshot.updateAlertSettings(for: MeasurementType.temperature, settings: .init(isOn: true))
        cell.refreshAlertStateIfNeeded()
        await flushAppBindings()
        XCTAssertTrue(button.isUserInteractionEnabled)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.alerts, [snapshot.id])
        snapshot.updateAlertConfig(
            for: MeasurementType.temperature, config: .init(isActive: true, isFiring: true, mutedTill: nil))
        cell.refreshAlertStateIfNeeded()
        await flushAppBindings()
        let badge = try XCTUnwrap(cell.allDescendants.compactMap { $0 as? AlertBellButton }.first)
        XCTAssertFalse(badge.isHidden)
        snapshot.removeAlertConfig(for: MeasurementType.temperature)
        cell.refreshAlertStateIfNeeded()
        await flushAppBindings()
        XCTAssertFalse(button.isUserInteractionEnabled)
        snapshot.metadata.isAlertAvailable = false
        cell.refreshAlertStateIfNeeded()
        await flushAppBindings()
        XCTAssertFalse(button.isUserInteractionEnabled)
    }

    private func labels(_ view: UIView) -> [String] { view.allDescendants.compactMap { ($0 as? UILabel)?.text } }
    private func indicator(_ type: MeasurementType, _ value: String, quality: MeasurementQualityState? = nil)
        -> RuuviTagCardSnapshotIndicatorData
    {
        .init(
            variant: .init(type: type), value: value, unit: "unit", isProminent: true,
            showSubscript: true, tintColor: .green, qualityState: quality)
    }
}
private final class DashboardCellOutputSpy: DashboardCellDelegate {
    var alerts = [String]()
    func didTapAlertButton(for snapshot: RuuviTagCardSnapshot) { alerts.append(snapshot.id) }
    func didChangeMoreButtonMenuPresentationState(for snapshot: RuuviTagCardSnapshot, isPresented: Bool) {}
}
