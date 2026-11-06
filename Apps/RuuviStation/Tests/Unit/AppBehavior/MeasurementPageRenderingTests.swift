import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class MeasurementPageRenderingTests: XCTestCase {
    func testLiveReadingsReuseCardsButTappingThemUsesTheLatestValue() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let controller = CardsMeasurementPageViewController()
        let output = MeasurementPageDelegateSpy()
        controller.delegate = output
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            indicator(.temperature, "20"), indicator(.co2, "700"), indicator(.pm25, "2.5"),
        ])
        controller.configure(with: fixture.snapshot)
        let host = try AppViewHost(controller)
        defer { host.close() }
        await flushAppBindings()
        let original = cards(controller)
        XCTAssertEqual(original.count, 2)
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            indicator(.temperature, "21"), indicator(.co2, "900"), indicator(.pm25, "3.5"),
        ])
        await flushAppBindings()
        XCTAssertEqual(cards(controller).map(ObjectIdentifier.init), original.map(ObjectIdentifier.init))
        original[0].onTap?()
        XCTAssertEqual(
            output.selected.last?.value, "900",
            "Opening details must use the latest reading, not the value captured when the card was built")
        XCTAssertTrue(controller.view.allDescendants.compactMap { ($0 as? UILabel)?.text }.contains("900"))
        let prominent = try XCTUnwrap(
            controller.view.allDescendants.compactMap { $0 as? CardsProminentIndicatorView }.first)
        controller.cardsProminentIndicatorViewDidTap(for: indicator(.temperature, "21"), sender: prominent)
        XCTAssertEqual(output.selected.last?.variant.type, .temperature)
        fixture.snapshot.metadata.isAlertAvailable = true
        fixture.snapshot.updateAlertConfig(
            for: MeasurementType.co2, config: .init(isActive: true, isFiring: true, mutedTill: nil))
        await flushAppBindings()
        XCTAssertTrue(original[0].isCurrentlyAlerting)
        fixture.snapshot.metadata.isAlertAvailable = false
        await flushAppBindings()
        XCTAssertFalse(original[0].isCurrentlyAlerting)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    func testChangingMeasurementOrderReordersCardsAndRemovingAllMeasurementsClearsTheGrid() async throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let controller = CardsMeasurementPageViewController()
        let output = MeasurementPageDelegateSpy()
        controller.delegate = output
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            indicator(.temperature, "20"), indicator(.co2, "700"), indicator(.pm25, "2.5"), indicator(.humidity, "50"),
        ])
        controller.configure(with: fixture.snapshot)
        let host = try AppViewHost(controller)
        defer { host.close() }
        await flushAppBindings()
        XCTAssertEqual(cards(controller).count, 3)
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [
            indicator(.temperature, "20"), indicator(.humidity, "50"), indicator(.pm25, "2.5"), indicator(.co2, "700"),
        ])
        await flushAppBindings()
        cards(controller).forEach { $0.onTap?() }
        XCTAssertEqual(output.selected.map { $0.variant.type }, [.humidity, .pm25, .co2])
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [])
        await flushAppBindings()
        XCTAssertTrue(cards(controller).isEmpty)
        let prominent = try XCTUnwrap(
            controller.view.allDescendants.compactMap { $0 as? CardsProminentIndicatorView }.first)
        XCTAssertNil(prominent.indicatorData)
        fixture.snapshot.displayData.indicatorGrid = .init(indicators: [indicator(.aqi, "80/100", quality: .good(80))])
        await flushAppBindings()
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        XCTAssertEqual(prominent.getCurrentHeight(), CardsProminentIndicatorView.heightForAQIMode())
        XCTAssertTrue(cards(controller).isEmpty)
    }

    private func cards(_ controller: UIViewController) -> [CardsMeasurementIndicatorView] {
        controller.view.allDescendants.compactMap { $0 as? CardsMeasurementIndicatorView }
    }
    private func indicator(_ type: MeasurementType, _ value: String, quality: MeasurementQualityState? = nil)
        -> RuuviTagCardSnapshotIndicatorData
    {
        .init(
            variant: .init(type: type), value: value, unit: "unit", isProminent: true,
            showSubscript: false, tintColor: nil, qualityState: quality)
    }
}
private final class MeasurementPageDelegateSpy: CardsMeasurementPageViewControllerDelegate {
    var selected = [RuuviTagCardSnapshotIndicatorData]()
    func cardsPageDidSelectMeasurementIndicator(
        _ indicator: RuuviTagCardSnapshotIndicatorData, in pageViewController: CardsMeasurementPageViewController
    ) {
        selected.append(indicator)
    }
}
