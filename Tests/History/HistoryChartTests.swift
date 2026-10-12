import DGCharts
import RuuviOntology
import UIKit
import XCTest

final class HistoryChartTests: XCTestCase {
    func testSynchronizedGraphsKeepSameTimeRangeWithDifferentPlotWidths() {
        let charts = [390.0, 280.0].map { width -> LineChartView in
            let chart = LineChartView(frame: CGRect(x: 0, y: 0, width: width, height: 260))
            chart.data = LineChartData(dataSet: LineChartDataSet(entries: [
                ChartDataEntry(x: 0, y: 0), ChartDataEntry(x: 100, y: 10),
            ]))
            chart.xAxis.axisMinimum = 0
            chart.xAxis.axisMaximum = 100
            chart.notifyDataSetChanged()
            chart.layoutIfNeeded()
            return chart
        }
        let source = charts[0], follower = charts[1]
        XCTAssertNotEqual(source.viewPortHandler.contentWidth, follower.viewPortHandler.contentWidth)
        source.viewPortHandler.refresh(
            newMatrix: CGAffineTransform(a: 4, b: 0, c: 0, d: 1, tx: -200, ty: 0),
            chart: source,
            invalidate: false
        )
        RuuviGraphHistoryViewport.synchronize(from: source, to: follower)
        XCTAssertEqual(source.lowestVisibleX, follower.lowestVisibleX, accuracy: 0.000001)
        XCTAssertEqual(source.highestVisibleX, follower.highestVisibleX, accuracy: 0.000001)
    }

    func testContinuousOverviewUsesOneDatasetDespiteWideSampleSpacing() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(1095 * 86400))
        let sampler = RuuviHistorySampler(range: range)
        for index in 0 ..< 105_120 {
            sampler.add(
                date: start.addingTimeInterval(Double(index * 900)),
                value: Double(index % 20)
            )
        }
        let data = RuuviHistoryChartData(
            series: sampler.finish(),
            selectedRange: range,
            sampledRange: range,
            upper: nil,
            lower: nil,
            showAlerts: false,
            drawDots: false
        )
        XCTAssertEqual(data.dataSetCount, 1)
        XCTAssertLessThanOrEqual(data.entryCount, 400)
        XCTAssertFalse(try (XCTUnwrap(data.dataSets[0] as? LineChartDataSet)).showGapBetweenPoints)
        XCTAssertEqual(data.statistics?.count, 105_120)
    }

    func testMultipleGapsAndSinglePointSegmentsRenderWithoutJoining() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let range = RuuviHistoryRange(start: start, end: start.addingTimeInterval(20000))
        let sampler = RuuviHistorySampler(range: range)
        for (time, value) in [(0.0, 1.0), (10.0, 2.0), (5000.0, 5.0), (10000.0, 3.0), (10010.0, 4.0)] {
            sampler.add(date: start.addingTimeInterval(time), value: value)
        }
        let data = RuuviHistoryChartData(
            series: sampler.finish(),
            selectedRange: range,
            sampledRange: range,
            upper: 4,
            lower: 1,
            showAlerts: true,
            drawDots: false
        )
        XCTAssertEqual(data.dataSets.map(\.entryCount), [2, 1, 2])
        XCTAssertTrue(try (XCTUnwrap(data.dataSets[1] as? LineChartDataSet)).drawCirclesEnabled)
        XCTAssertTrue(data.dataSets.allSatisfy { ($0 as? LineChartDataSet)?.hasAlertRange == true })
        let chart = LineChartView(frame: CGRect(x: 0, y: 0, width: 390, height: 260))
        chart.data = data
        chart.xAxis.axisMinimum = range.start.timeIntervalSince1970
        chart.xAxis.axisMaximum = range.end.timeIntervalSince1970
        chart.notifyDataSetChanged()
        chart.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: chart.bounds.size)
            .image { context in chart.layer.render(in: context.cgContext) }
        XCTAssertEqual(image.size.width, 390)
        XCTAssertNotNil(image.pngData())
    }
}

final class HistoryRefreshTests: XCTestCase {
    func testPageBurstProducesOneMainThreadRefresh() {
        let refreshed = expectation(description: "One refresh for a burst of pages")
        refreshed.assertForOverFulfill = true
        var count = 0
        let scheduler = RuuviGraphHistoryRefresh(interval: 0.02) {
            XCTAssertTrue(Thread.isMainThread)
            count += 1
            refreshed.fulfill()
        }
        for _ in 0 ..< 100 {
            scheduler.schedule()
        }
        wait(for: [refreshed], timeout: 1)
        XCTAssertEqual(count, 1)
        scheduler.flush()
        XCTAssertEqual(count, 1)
    }

    func testCompletionFlushesFinalPageWithoutDelayedDuplicate() {
        var count = 0
        let duplicate = expectation(description: "No duplicate after completion")
        duplicate.isInverted = true
        let scheduler = RuuviGraphHistoryRefresh(interval: 0.02) {
            count += 1
            if count > 1 { duplicate.fulfill() }
        }
        scheduler.schedule()
        scheduler.flush()
        XCTAssertEqual(count, 1)
        wait(for: [duplicate], timeout: 0.1)
    }

    func testCancelledSensorDoesNotRefreshAndNextSensorCanSchedule() {
        var count = 0
        let refreshed = expectation(description: "Only the new sensor refreshes")
        refreshed.assertForOverFulfill = true
        let scheduler = RuuviGraphHistoryRefresh(interval: 0.02) {
            count += 1
            refreshed.fulfill()
        }
        scheduler.schedule()
        scheduler.cancel()
        scheduler.schedule()
        wait(for: [refreshed], timeout: 1)
        XCTAssertEqual(count, 1)
        scheduler.cancel()
    }

    func testReleasedSchedulerDoesNotRefresh() {
        let refreshed = expectation(description: "No refresh after graph closes")
        refreshed.isInverted = true
        var scheduler: RuuviGraphHistoryRefresh? = RuuviGraphHistoryRefresh(interval: 0.02) { refreshed.fulfill() }
        scheduler?.schedule()
        scheduler = nil
        wait(for: [refreshed], timeout: 0.1)
    }
}

final class HistoryScanTests: XCTestCase {
    func testPageUpdatesDoNotCancelActiveScanAndRequestOneFollowup() throws {
        let scan = RuuviGraphHistoryScan<String>()
        let first = try XCTUnwrap(scan.begin("three-year-overview"))
        for _ in 0 ..< 100 {
            XCTAssertNil(scan.begin("three-year-overview"))
        }
        XCTAssertFalse(first.isCancelled)
        XCTAssertTrue(scan.finish(first))
        let followup = try XCTUnwrap(scan.begin("three-year-overview"))
        XCTAssertFalse(scan.finish(followup))
    }

    func testZoomCancelsOverviewAndIgnoresItsLateCompletion() throws {
        let scan = RuuviGraphHistoryScan<String>()
        let overview = try XCTUnwrap(scan.begin("overview"))
        let zoom = try XCTUnwrap(scan.begin("visible-hour"))
        XCTAssertTrue(overview.isCancelled)
        XCTAssertFalse(zoom.isCancelled)
        XCTAssertFalse(scan.finish(overview))
        XCTAssertNil(scan.begin("visible-hour"))
        XCTAssertTrue(scan.finish(zoom))
    }

    func testSuspendedScanCanRestartSameViewport() throws {
        let scan = RuuviGraphHistoryScan<String>()
        let beforeBackground = try XCTUnwrap(scan.begin("visible-hour"))
        beforeBackground.cancel()
        let afterForeground = try XCTUnwrap(scan.begin("visible-hour"))
        XCTAssertFalse(afterForeground.isCancelled)
        XCTAssertFalse(scan.finish(beforeBackground))
        XCTAssertFalse(scan.finish(afterForeground))
    }
}
