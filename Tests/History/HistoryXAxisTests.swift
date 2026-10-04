import DGCharts
import UIKit
import XCTest

final class HistoryXAxisTests: XCTestCase {
    private func makeChart(width: CGFloat = 320) -> LineChartView {
        let chart = LineChartView(frame: CGRect(x: 0, y: 0, width: width, height: 220))
        chart.xAxis.labelFont = .systemFont(ofSize: 12)
        chart.xAxis.setLabelCount(5, force: false)
        chart.xAxis.valueFormatter = XAxisValueFormatter()
        chart.xAxis.labelPosition = .bottom
        chart.rightAxis.enabled = false
        chart.legend.enabled = false
        chart.xAxisRenderer = CustomXAxisRenderer(
            from: 0,
            viewPortHandler: chart.viewPortHandler,
            axis: chart.xAxis,
            transformer: chart.getTransformer(forAxis: .left)
        )
        return chart
    }

    func testLongRangesHaveReadableLabelsOnPhoneAndTablet() throws {
        for width: CGFloat in [240, 320, 700] {
            for days in [10, 30, 60, 100, 365, 730, 1095] {
                let chart = makeChart(width: width)
                let start = Date(timeIntervalSince1970: 1_780_000_000).timeIntervalSince1970
                let end = start + Double(days) * 86400
                chart.xAxisRenderer.computeAxisValues(min: start, max: end)
                let entries = chart.xAxis.entries
                XCTAssertGreaterThanOrEqual(entries.count, 2, "width: \(width), days: \(days)")
                XCTAssertLessThanOrEqual(entries.count, 5)
                let labels = entries.map { chart.xAxis.valueFormatter!.stringForValue($0, axis: chart.xAxis) }
                XCTAssertEqual(Set(labels).count, labels.count)
                for index in 1 ..< entries.count {
                    let gap = (entries[index] - entries[index - 1]) / (end - start) *
                        Double(chart.viewPortHandler.contentWidth)
                    let widths = [labels[index - 1], labels[index]].map {
                        ($0 as NSString).size(withAttributes: [.font: chart.xAxis.labelFont]).width
                    }
                    XCTAssertGreaterThanOrEqual(gap, Double(widths.reduce(0, +)) / 2 + 12)
                }
            }
        }
    }

    func testZoomChangesFromDatesToClockTimes() throws {
        let chart = makeChart()
        let start = Date(timeIntervalSince1970: 1_780_000_000).timeIntervalSince1970
        chart.xAxisRenderer.computeAxisValues(min: start, max: start + 1095 * 86400)
        let formatter = try XCTUnwrap(chart.xAxis.valueFormatter as? XAxisValueFormatter)
        XCTAssertGreaterThanOrEqual(formatter.tickInterval, 86400)
        for entry in chart.xAxis.entries {
            let year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: entry))
            XCTAssertTrue(formatter.stringForValue(entry, axis: chart.xAxis).contains(String(year)))
        }
        chart.xAxisRenderer.computeAxisValues(min: start, max: start + 3600)
        XCTAssertLessThan(formatter.tickInterval, 86400)
        XCTAssertGreaterThanOrEqual(chart.xAxis.entries.count, 2)
        XCTAssertTrue(chart.xAxis.entries.allSatisfy { $0 >= start && $0 <= start + 3600 })
    }

    func testDailyTicksRemainAtLocalMidnightAcrossDST() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Oslo"))
        for month in [3, 10] {
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: 23)))
            let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 8, to: start))
            let chart = makeChart()
            let renderer = try XCTUnwrap(chart.xAxisRenderer as? CustomXAxisRenderer)
            renderer.calendar = calendar
            renderer.computeAxisValues(min: start.timeIntervalSince1970, max: end.timeIntervalSince1970)
            XCTAssertGreaterThanOrEqual(chart.xAxis.entries.count, 3)
            for entry in chart.xAxis.entries {
                let date = Date(timeIntervalSince1970: entry)
                XCTAssertEqual(date, calendar.startOfDay(for: date))
            }
        }
    }

    func testFractionalTimeZoneTicksAlignToLocalClock() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kathmandu"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 8)))
        let chart = makeChart()
        let renderer = try XCTUnwrap(chart.xAxisRenderer as? CustomXAxisRenderer)
        renderer.calendar = calendar
        renderer.computeAxisValues(min: start.timeIntervalSince1970, max: start.timeIntervalSince1970 + 12 * 3600)
        XCTAssertGreaterThanOrEqual(chart.xAxis.entries.count, 3)
        for entry in chart.xAxis.entries {
            XCTAssertEqual(calendar.component(.minute, from: Date(timeIntervalSince1970: entry)), 0)
        }
    }

    func testAxisRendersOverviewAndZoomedRange() throws {
        let chart = makeChart(width: 390)
        chart.backgroundColor = .white
        let start = Date(timeIntervalSince1970: 1_780_000_000).timeIntervalSince1970
        let entries = (0 ..< 400).map { index in
            ChartDataEntry(x: start + Double(index) / 399 * 1095 * 86400, y: 20 + sin(Double(index) / 10))
        }
        let dataSet = LineChartDataSet(entries: entries)
        dataSet.drawCirclesEnabled = false
        dataSet.drawValuesEnabled = false
        chart.data = LineChartData(dataSet: dataSet)
        chart.xAxis.axisMinimum = start
        chart.xAxis.axisMaximum = start + 1095 * 86400
        chart.notifyDataSetChanged()
        chart.layoutIfNeeded()
        for scale in [1.0, 26280.0] {
            chart.viewPortHandler.refresh(
                newMatrix: CGAffineTransform(scaleX: scale, y: 1),
                chart: chart,
                invalidate: true
            )
            let image = UIGraphicsImageRenderer(size: chart.bounds.size).image { chart.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "History X axis scale \(scale)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-axis-\(Int(scale)).png")
            try image.pngData()?.write(to: url)
            print("AXIS_IMAGE: \(url.path)")
            XCTAssertFalse(chart.xAxis.entries.isEmpty)
        }
    }
}
