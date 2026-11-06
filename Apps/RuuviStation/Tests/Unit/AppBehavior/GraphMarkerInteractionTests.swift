import DGCharts
import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class GraphMarkerInteractionTests: XCTestCase {
    func testProgrammaticHighlightUsesNearestReadingClampsDatasetAndClearsEmptyCharts() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let chart = makeChart(fixture)
        chart.highlightEntry(atX: 18, closestToY: 22, dataSetIndex: 99)
        XCTAssertEqual(chart.highlighted.first?.x, 20)
        XCTAssertEqual(chart.highlighted.first?.dataSetIndex, 0)
        chart.highlightEntry(atX: 10, closestToY: 10, dataSetIndex: -4)
        XCTAssertEqual(chart.highlighted.first?.x, 10)
        XCTAssertGreaterThan(chart.highestVisibleY, chart.lowestVisibleY)
        XCTAssertGreaterThanOrEqual(chart.lowestVisibleY, chart.leftAxis.axisMinimum)
        XCTAssertLessThanOrEqual(chart.highestVisibleY, chart.leftAxis.axisMaximum)
        chart.clearMarker()
        XCTAssertTrue(chart.highlighted.isEmpty)
        chart.data = LineChartData(dataSet: LineChartDataSet(entries: []))
        chart.highlightEntry(atX: 10, closestToY: 10, dataSetIndex: 0)
        XCTAssertTrue(chart.highlighted.isEmpty)
        chart.data = LineChartData()
        chart.highlightEntry(atX: 10, closestToY: 10, dataSetIndex: 0)
        XCTAssertTrue(chart.highlighted.isEmpty)
        chart.data = nil
        chart.highlightEntry(atX: 10, closestToY: 10, dataSetIndex: 0)
        XCTAssertTrue(chart.highlighted.isEmpty)
    }

    func testLongPressPinsAReadingDisablesPanningAndRestoresItWhenInteractionEnds() throws {
        let fixture = MeasurementFixture()
        defer { fixture.cleanup() }
        let chart = makeChart(fixture)
        let output = GraphMarkerDelegateSpy()
        chart.chartDelegate = output
        let first = try XCTUnwrap(chart.data?.dataSets.first?.entryForIndex(0))
        let second = try XCTUnwrap(chart.data?.dataSets.first?.entryForIndex(1))
        let gesture = GraphMarkerLongPress()
        gesture.point = chart.getPosition(entry: first, axis: .left)
        gesture.eventState = .began
        chart.perform(NSSelectorFromString("handleLongPress:"), with: gesture)
        XCTAssertEqual(output.begins, 1)
        XCTAssertFalse(chart.dragEnabled)
        XCTAssertEqual(output.selected.last?.x, first.x)
        gesture.point = chart.getPosition(entry: second, axis: .left)
        gesture.eventState = .changed
        chart.perform(NSSelectorFromString("handleLongPress:"), with: gesture)
        XCTAssertEqual(output.selected.last?.x, second.x)
        gesture.eventState = .ended
        chart.perform(NSSelectorFromString("handleLongPress:"), with: gesture)
        XCTAssertTrue(chart.dragEnabled)
        XCTAssertEqual(output.ends, 1)
        chart.chartValueNothingSelected(chart)
        XCTAssertEqual(chart.highlighted.first?.x, second.x, "A pinned marker survives chart deselection callbacks")
        XCTAssertEqual(output.deselections, 0)
        chart.clearMarker()
        chart.chartValueNothingSelected(chart)
        chart.chartValueNothingSelected(chart)
        XCTAssertGreaterThanOrEqual(output.deselections, 1)
        let tap = GraphMarkerTap()
        tap.point = CGPoint(x: 5, y: 5)
        tap.eventState = .ended
        chart.perform(NSSelectorFromString("handleTap:"), with: tap)
        XCTAssertEqual(output.taps, [tap.point])
        chart.chartTranslated(chart, dX: 2, dY: 3)
        chart.chartScaled(chart, scaleX: 2, scaleY: 1)
        XCTAssertEqual(output.translations, 2)
    }

    func testSelectingAReadingSynchronizesMarkersAcrossAllVisibleCharts() throws {
        let fixture = try GraphViewFixture()
        defer { fixture.close() }
        fixture.loadCharts()
        let first = try XCTUnwrap(fixture.charts.first)
        let entry = try XCTUnwrap(first.underlyingView.data?.dataSets.first?.entryForIndex(1))
        fixture.controller.chartValueDidSelect(
            first, entry: entry,
            highlight: Highlight(x: entry.x, y: entry.y, dataSetIndex: 0))
        for chart in fixture.charts where chart !== first {
            XCTAssertEqual(chart.underlyingView.highlighted.first?.x, entry.x)
        }
        fixture.controller.chartValueDidDeselect(first)
        XCTAssertTrue(fixture.charts.allSatisfy { $0.underlyingView.highlighted.isEmpty })
    }

    private func makeChart(_ fixture: MeasurementFixture) -> CardsGraphInternalView {
        let chart = CardsGraphInternalView(source: .cards, graphType: .temperature)
        chart.frame = CGRect(x: 0, y: 0, width: 360, height: 240)
        chart.setSettings(settings: fixture.settings)
        chart.data = LineChartData(
            dataSet: LineChartDataSet(entries: [
                ChartDataEntry(x: 10, y: 10), ChartDataEntry(x: 20, y: 22), ChartDataEntry(x: 30, y: 15),
            ]))
        chart.setMarker(with: .temperature, measurementService: fixture.measurement, unit: "°C")
        chart.setYAxisLimit(min: 8, max: 24)
        chart.setXAxisRenderer(showAll: true)
        chart.notifyDataSetChanged()
        chart.layoutIfNeeded()
        return chart
    }
}

private final class GraphMarkerLongPress: UILongPressGestureRecognizer {
    var point = CGPoint.zero
    var eventState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set { eventState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
}
private final class GraphMarkerTap: UITapGestureRecognizer {
    var point = CGPoint.zero
    var eventState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { eventState }
        set { eventState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
}
private final class GraphMarkerDelegateSpy: NSObject, CardsGraphInternalViewDelegate {
    var begins = 0
    var ends = 0
    var selected = [ChartDataEntry]()
    var deselections = 0
    var translations = 0
    var taps = [CGPoint]()
    func chartDidTranslate(_ chartView: CardsGraphInternalView) { translations += 1 }
    func chartValueDidSelect(_ chartView: CardsGraphInternalView, entry: ChartDataEntry, highlight: Highlight) {
        selected.append(entry)
    }
    func chartValueDidDeselect(_ chartView: CardsGraphInternalView) { deselections += 1 }
    func chartDidSingleTap(_ chartView: CardsGraphInternalView, location: CGPoint) { taps.append(location) }
    func chartMarkerInteractionDidBegin(_ chartView: CardsGraphInternalView) { begins += 1 }
    func chartMarkerInteractionDidEnd(_ chartView: CardsGraphInternalView) { ends += 1 }
}
