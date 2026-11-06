import RuuviLocalization
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class ProminentIndicatorTests: XCTestCase {
    func testProminentMeasurementShowsValueUnitAndAlertStateAndClearsWhenRemoved() {
        let view = CardsProminentIndicatorView()
        view.frame = CGRect(x: 0, y: 0, width: 340, height: 300)
        view.indicatorData = indicator(.temperature, value: "21.5", unit: "°C")
        view.layoutIfNeeded()
        XCTAssertTrue(labels(view).contains("21.5"))
        XCTAssertTrue(labels(view).contains("°C"))
        XCTAssertEqual(view.getCurrentHeight(), CardsProminentIndicatorView.heightForMeasurementMode())
        XCTAssertEqual(view.getCurrentHeight(), CardsProminentIndicatorView.getMeasurementProminentHeight())
        view.updateAlertState(isHighlighted: true)
        view.updateAlertState(isHighlighted: true)
        XCTAssertTrue(view.isCurrentlyAlerting)
        XCTAssertTrue(
            view.allDescendants.compactMap { $0 as? UILabel }.contains {
                $0.text == "21.5" && $0.textColor == RuuviColor.orangeColor.color
            })
        view.restartAlertAnimationIfNeeded()
        view.indicatorData = nil
        XCTAssertFalse(view.isCurrentlyAlerting)
        XCTAssertTrue(view.subviews.allSatisfy(\.isHidden))
        view.restartAlertAnimationIfNeeded()
    }

    func testAqiChangingToAnUnavailableReadingCannotLeaveThePreviousValueVisible() {
        let view = CardsProminentIndicatorView()
        view.frame = CGRect(x: 0, y: 0, width: 340, height: 300)
        view.indicatorData = indicator(.aqi, value: "85/100", unit: "", quality: .good(85))
        view.layoutIfNeeded()
        XCTAssertTrue(labels(view).contains("85"))
        XCTAssertEqual(view.getCurrentHeight(), CardsProminentIndicatorView.heightForAQIMode())
        XCTAssertEqual(view.getCurrentHeight(), CardsProminentIndicatorView.getAQIProminentHeight())
        view.indicatorData = indicator(.aqi, value: "unavailable", unit: "", quality: .undefined(0))
        XCTAssertTrue(labels(view).contains(RuuviLocalization.na))
        XCTAssertFalse(labels(view).contains("85"), "An invalid new reading must not display a stale good AQI")
        view.indicatorData = indicator(.aqi, value: "42", unit: "", quality: .poor(42))
        XCTAssertTrue(labels(view).contains("42"))
        view.indicatorData = indicator(.aqi, value: "42", unit: "", quality: nil)
        XCTAssertTrue(labels(view).contains(RuuviLocalization.na))
    }

    func testAqiStatusAndAlertRenderingFollowEachQualityStateWithoutLayerAccumulation() throws {
        let view = AirQualityCircularView(frame: CGRect(x: 0, y: 0, width: 176, height: 176))
        for state: MeasurementQualityState in [
            .excellent(100), .good(80), .fair(60), .poor(40), .veryPoor(20), .undefined(0),
        ] {
            view.setValue(80, state: state)
            view.layoutIfNeeded()
            XCTAssertTrue(labels(view).contains(state.title))
            XCTAssertTrue(labels(view).contains("/100"))
            view.updateAlertState(isHighlighted: true)
            view.updateAlertState(isHighlighted: false)
        }
        let progress = try XCTUnwrap(view.allDescendants.compactMap { $0 as? CircularProgressView }.first)
        progress.animateProgress = true
        let layerCount = progress.layer.sublayers?.count
        for value: Float in [-1, 0, 0.5, 1, 2] {
            progress.setProgress(value, animated: true)
            progress.setNeedsLayout(); progress.layoutIfNeeded()
            XCTAssertEqual(progress.layer.sublayers?.count, layerCount)
            let arcs = progress.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.filter { $0.lineWidth > 1 } ?? []
            XCTAssertTrue(arcs.contains { abs($0.strokeEnd - CGFloat(max(0, min(1, value)))) < 0.001 })
            XCTAssertTrue(arcs.allSatisfy { $0.strokeEnd.isFinite && $0.strokeEnd >= 0 && $0.strokeEnd <= 1 })
        }
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { view.layer.render(in: $0.cgContext) }
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 2000)
        let attachment = XCTAttachment(image: image)
        attachment.name = "AQI indicator rendering"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func labels(_ view: UIView) -> [String] { view.allDescendants.compactMap { ($0 as? UILabel)?.text } }
    private func indicator(
        _ type: MeasurementType, value: String, unit: String,
        quality: MeasurementQualityState? = nil
    ) -> RuuviTagCardSnapshotIndicatorData {
        .init(
            variant: .init(type: type), value: value, unit: unit, isProminent: true,
            showSubscript: false, tintColor: nil, qualityState: quality)
    }
}
