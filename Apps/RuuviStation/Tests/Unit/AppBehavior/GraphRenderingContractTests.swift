import DGCharts
import RuuviOntology
import UIKit
import Vision
import XCTest
@testable import station

@MainActor final class GraphRenderingContractTests: XCTestCase {
    func testMarkerKeepsReadingsInsideTheChartAtBothEdgesAndAboveOrBelowThePoint() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let chart = LineChartView(frame: CGRect(x: 0, y: 0, width: 360, height: 240))
        let marker = CardsGraphMarkerView(color: nil, font: .systemFont(ofSize: 18))
        marker.chartView = chart
        XCTAssertEqual(marker.color, .darkGray)
        marker.initialise(with: "ppm", type: .co2, measurementService: fixture.measurement, parentFrame: chart.bounds)
        marker.refreshContent(entry: .init(x: 1_700_000_000, y: 823.456), highlight: .init(x: 0, y: 0, dataSetIndex: 0))
        for point in [CGPoint(x: 1, y: 5), CGPoint(x: 359, y: 5), CGPoint(x: 180, y: 190)] {
            let image = UIGraphicsImageRenderer(bounds: chart.bounds).image {
                marker.draw(context: $0.cgContext, point: point)
            }
            let rect = marker.lastDrawnRect
            XCTAssertGreaterThan(rect.width, 30)
            XCTAssertGreaterThan(rect.height, 20)
            XCTAssertGreaterThanOrEqual(rect.minX, 0)
            XCTAssertLessThanOrEqual(rect.maxX, chart.bounds.width)
            XCTAssertGreaterThanOrEqual(rect.minY, 0)
            XCTAssertLessThanOrEqual(rect.maxY, chart.bounds.height - 32)
            if point.y < 10 { XCTAssertGreaterThan(rect.minY, point.y) } else { XCTAssertLessThan(rect.maxY, point.y) }
            let text = try recognizedText(image).replacingOccurrences(of: ",", with: ".")
            XCTAssertTrue(text.contains("823.46"), text)
        }
    }

    func testAirQualityMarkerUsesOneDecimalAndFallbackPlacementRemainsFiniteInAShortChart() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let marker = CardsGraphMarkerView(font: .monospacedSystemFont(ofSize: 24, weight: .regular))
        marker.initialise(
            with: "AQI", type: .aqi, measurementService: fixture.measurement,
            parentFrame: CGRect(x: 0, y: 0, width: 360, height: 240))
        marker.refreshContent(entry: .init(x: 1_700_000_000, y: 83.456), highlight: .init(x: 0, y: 0, dataSetIndex: 0))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 240)).image {
            marker.draw(context: $0.cgContext, point: CGPoint(x: 180, y: 120))
        }
        let text = try recognizedText(image).replacingOccurrences(of: ",", with: ".")
        XCTAssertTrue(text.contains("83.5"), text)
        XCTAssertTrue(text.contains("AQI"), text)
        let attachment = XCTAttachment(image: image)
        attachment.name = "AQI graph marker"
        attachment.lifetime = .keepAlways
        add(attachment)
        marker.initialise(
            with: "AQI", type: .aqi, measurementService: fixture.measurement,
            parentFrame: CGRect(x: 0, y: 0, width: 360, height: 40))
        for y: CGFloat in [0, 40] {
            _ = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 80)).image {
                marker.draw(context: $0.cgContext, point: CGPoint(x: 180, y: y))
            }
            XCTAssertTrue(marker.lastDrawnRect.origin.y.isFinite)
            XCTAssertGreaterThan(marker.lastDrawnRect.height, 0)
        }
    }

    func testAirQualityAxisKeepsItsFiveThresholdsAndHonorsHiddenLabels() throws {
        let chart = CardsGraphInternalView(source: .mesurementDetails, graphType: .aqi)
        chart.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        chart.extraLeftOffset = 60
        chart.leftAxis.labelFont = .systemFont(ofSize: 20)
        chart.leftAxis.labelTextColor = .black
        chart.data = LineChartData(dataSet: LineChartDataSet(entries: [.init(x: 0, y: 20), .init(x: 1, y: 95)]))
        chart.setYAxisLimit(min: 20, max: 95)
        chart.notifyDataSetChanged()
        chart.layoutIfNeeded()
        let renderer = try XCTUnwrap(chart.leftYAxisRenderer as? AQIYAxisRenderer)
        renderer.computeAxisValues(min: 20, max: 95)
        XCTAssertEqual(chart.leftAxis.entries, [10, 50, 80, 90, 100])
        XCTAssertEqual(chart.leftAxis.axisMinimum, 0)
        XCTAssertEqual(chart.leftAxis.axisMaximum, 100)
        let positions = renderer.transformedPositions()
        XCTAssertEqual(positions.count, 5)
        XCTAssertGreaterThan(positions[0].y, positions[4].y)
        let render = {
            UIGraphicsImageRenderer(bounds: chart.bounds).image {
                UIColor.white.setFill()
                $0.fill(chart.bounds)
                renderer.renderAxisLabels(context: $0.cgContext)
            }
        }
        chart.leftAxis.labelFont = .systemFont(ofSize: 20)
        chart.leftAxis.labelTextColor = .black
        chart.leftAxis.valueFormatter = nil
        let visible = render()
        let text = try recognizedText(visible)
        XCTAssertTrue(text.contains("50"), text)
        chart.leftAxis.drawLabelsEnabled = false
        XCTAssertEqual(try recognizedText(render()), "")
        chart.leftAxis.drawLabelsEnabled = true
        chart.leftAxis.enabled = false
        XCTAssertEqual(try recognizedText(render()), "")
    }

    private func recognizedText(_ image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.customWords = ["AQI", "ppm"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return request.results?.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ") ?? ""
    }
}
