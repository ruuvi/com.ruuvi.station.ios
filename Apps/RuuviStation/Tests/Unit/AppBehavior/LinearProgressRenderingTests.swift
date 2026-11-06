import RuuviLocalization
import UIKit
import XCTest
@testable import station

@MainActor final class LinearProgressRenderingTests: XCTestCase {
    func testValuesClampToTheTrackAndChangingColorDoesNotAccumulateGlowLayers() throws {
        let view = DashboardLinearProgressView(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        view.layoutIfNeeded()
        XCTAssertEqual(view.intrinsicContentSize.height, 16)
        for (value, fraction) in [(-10, 0.0), (0, 0.0), (25, 0.25), (100, 1.0), (200, 1.0)] {
            view.setValue(value, progressTintColor: .red)
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let shapes = view.layer.sublayers?.compactMap { $0 as? CAShapeLayer } ?? []
            XCTAssertEqual(shapes.count, 4)
            let track = try XCTUnwrap(shapes.first?.path).boundingBoxOfPath
            let fill = try XCTUnwrap(shapes.dropFirst().first?.path).boundingBoxOfPath
            XCTAssertEqual(fill.width, track.width * fraction, accuracy: 0.01)
            XCTAssertEqual(shapes[1].fillColor, UIColor.red.cgColor)
            XCTAssertEqual(shapes[2].sublayers?.count, 4)
            XCTAssertTrue(track.minX >= 0 && track.maxX <= view.bounds.width)
        }
        view.setValue(40, maxValue: 80, progressTintColor: nil)
        let shapes = try XCTUnwrap(view.layer.sublayers?.compactMap { $0 as? CAShapeLayer })
        XCTAssertEqual(shapes[1].fillColor, RuuviColor.ruuviAQILinePlaceholderColor.color.cgColor)
        XCTAssertEqual(
            try XCTUnwrap(shapes[1].path).boundingBoxOfPath.width,
            try XCTUnwrap(shapes[0].path).boundingBoxOfPath.width / 2, accuracy: 0.01)
    }

    func testAnimatedProgressSettlesOnTheRequestedValueAndRemovesAnimations() async throws {
        let controller = UIViewController()
        let host = try AppViewHost(controller)
        defer { host.close() }
        let view = DashboardLinearProgressView(frame: CGRect(x: 20, y: 100, width: 200, height: 20))
        controller.view.addSubview(view)
        view.layoutIfNeeded()
        view.animateProgress = true
        view.setProgress(0.75, animated: true)
        let shapes = try XCTUnwrap(view.layer.sublayers?.compactMap { $0 as? CAShapeLayer })
        XCTAssertNotNil(shapes[1].animation(forKey: "progress"))
        XCTAssertNotNil(shapes[3].animation(forKey: "tipPosition"))
        await waitForAppState("progress animation settled") { shapes[1].animationKeys()?.isEmpty != false }
        XCTAssertNil(shapes[3].animation(forKey: "tipPosition"))
        XCTAssertEqual(
            try XCTUnwrap(shapes[1].path).boundingBoxOfPath.width,
            try XCTUnwrap(shapes[0].path).boundingBoxOfPath.width * 0.75, accuracy: 0.01)
    }

    func testSmallAndEmptyBoundsRemainFiniteAndCanGrowBackIntoAVisibleTrack() throws {
        let view = DashboardLinearProgressView(frame: .zero)
        view.setProgress(0.5)
        XCTAssertTrue(view.layer.sublayers?.isEmpty != false)
        for size in [CGSize(width: 6, height: 4), CGSize(width: 240, height: 20)] {
            view.frame.size = size
            view.setNeedsLayout()
            view.layoutIfNeeded()
            let layers = try XCTUnwrap(view.layer.sublayers?.compactMap { $0 as? CAShapeLayer })
            XCTAssertEqual(layers.count, 4)
            for layer in [layers[0], layers[1], layers[3]] {
                let bounds = try XCTUnwrap(layer.path).boundingBoxOfPath
                XCTAssertTrue(bounds.width.isFinite && bounds.height.isFinite)
                XCTAssertGreaterThan(bounds.width, 0)
            }
        }
    }
}
