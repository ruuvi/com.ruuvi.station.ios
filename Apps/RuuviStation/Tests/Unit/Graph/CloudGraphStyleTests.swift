@testable import station
@testable import RuuviLocal
import DGCharts
import RuuviCloud
import RuuviOntology
import UIKit
import XCTest

@MainActor
final class CloudGraphStyleTests: XCTestCase {
    func testCloudAndExistingRendererProduceIdenticalPlots() throws {
        let settings = RuuviLocalSettingsUserDefaults()
        let savedDots = settings.chartDrawDotsOn
        let savedTemperatureUnit = settings.temperatureUnit
        settings.temperatureUnit = .celsius
        defer {
            settings.chartDrawDotsOn = savedDots
            settings.temperatureUnit = savedTemperatureUnit
        }
        let cases: [[(Int, Double)]] = [
            [(7200, 20)],
            [(3600, 20), (3660, 22), (3720, 18), (3780, 21)],
            [(3600, 20), (10800, 22), (18000, 18), (25200, 21)],
            [(3600, 20), (3660, 22), (14400, 18), (21600, 21), (21660, 19)],
        ]
        for (caseIndex, samples) in cases.enumerated() {
            for dots in [false, true] {
                settings.chartDrawDotsOn = dots
                for alerts in [false, true] {
                    let model = try XCTUnwrap(CloudGraphAdapter.model(
                        viewport: CloudGraphViewport(overview: series(samples)),
                        variant: MeasurementDisplayVariant(type: .temperature), settings: settings,
                        lowerAlertValue: 19, upperAlertValue: 21, showAlertRangeInGraph: alerts
                    ))
                    let actual = try XCTUnwrap(model.chartData)
                    let referenceSet = RuuviGraphDataSetFactory.newDataSet(
                        upperAlertValue: 21, entries: samples.map { ChartDataEntry(x: Double($0.0), y: $0.1) },
                        lowerAlertValue: 19, showAlertRangeInGraph: alerts
                    )
                    // The original main presenter applies this rule to the whole chart.
                    referenceSet.circleRadius = samples.count == 1 ? 6 : 0.8
                    referenceSet.drawCirclesEnabled = samples.count == 1 || dots
                    let reference = LineChartData(dataSet: referenceSet)
                    XCTAssertEqual(actual.dataSetCount, 1)
                    let actualSet = try XCTUnwrap(actual.dataSets.first as? LineChartDataSet)
                    XCTAssertEqual(actualSet.hasAlertRange, alerts)
                    XCTAssertEqual(actualSet.fillColor, referenceSet.fillColor)
                    XCTAssertEqual(actualSet.fillAlpha, referenceSet.fillAlpha)
                    XCTAssertEqual(actualSet.highlightLineDashLengths, referenceSet.highlightLineDashLengths)
                    for zoomed in [false, true] {
                        let expectedImage = render(reference, zoomed: zoomed)
                        let actualImage = render(actual, zoomed: zoomed)
                        XCTAssertEqual(actualImage.pngData(), expectedImage.pngData(),
                                       "Plot mismatch: case \(caseIndex), dots \(dots), alerts \(alerts), zoom \(zoomed)")
                        if caseIndex == 2 && !dots && !alerts && !zoomed {
                            for (name, image) in [("existing sparse style", expectedImage), ("cloud sparse style", actualImage)] {
                                let attachment = XCTAttachment(image: image)
                                attachment.name = name
                                attachment.lifetime = .keepAlways
                                add(attachment)
                            }
                        }
                    }
                }
            }
        }
    }

    private func render(_ data: LineChartData, zoomed: Bool) -> UIImage {
        let chart = CardsGraphInternalView(frame: CGRect(x: 0, y: 0, width: 420, height: 260))
        chart.backgroundColor = UIColor(red: 0, green: 0.12, blue: 0.11, alpha: 1)
        chart.data = data
        chart.xAxis.axisMinimum = 0
        chart.xAxis.axisMaximum = 28800
        chart.leftAxis.axisMinimum = 0
        chart.leftAxis.axisMaximum = 30
        chart.notifyDataSetChanged()
        chart.layoutIfNeeded()
        if zoomed { chart.zoom(scaleX: 2, scaleY: 1, x: 210, y: 130) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: chart.bounds.size, format: format).image { _ in
            chart.draw(chart.bounds)
        }
    }

    private func series(_ samples: [(Int, Double)]) throws -> CloudGraphSeries {
        let points: [[String: Any]] = samples.map { time, value in
            ["timestamp": time, "metrics": ["temperature": [
                "mean": value, "min": value, "max": value, "count": 1,
            ],],]
        }
        return try JSONDecoder().decode(CloudGraphSeries.self, from: JSONSerialization.data(withJSONObject: [
            "sensor": "AA:BB:CC:DD:EE:FF", "name": "Synthetic", "since": 0, "until": 28800,
            "resolutionSeconds": 60, "offsetTemperature": 0, "offsetHumidity": 0, "offsetPressure": 0,
            "points": points,
        ]))
    }
}
