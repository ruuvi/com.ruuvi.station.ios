@testable import station
@testable import RuuviCloud
@testable import RuuviLocal
import RuuviOntology
import RuuviService
import DGCharts
import UIKit
import XCTest

@MainActor
final class CloudGraphIntegrationTests: XCTestCase {
    func testThreeYearOverviewZoomPanAndShortDurationKeepTheSameTimelineAndBoundedData() async throws {
        let settings = RuuviLocalSettingsUserDefaults()
        let output = GraphTestOutput()
        let controller = CardsGraphViewController(output: output, settings: settings)
        controller.measurementService = RuuviServiceMeasurementImpl(settings: settings,
                                                                  emptyValueString: "—", percentString: "%")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.setCloudHistoryLimit(hours: 1095 * 24)
        let variants: [MeasurementDisplayVariant] = [.init(type: .temperature), .init(type: .humidity), .init(type: .pressure)]
        controller.createChartViews(from: variants)
        let initial = expectation(description: "three year overview rendered")
        let detail = expectation(description: "zoomed detail rendered")
        let pan = expectation(description: "panned detail rendered")
        let short = expectation(description: "one hour rendered")
        var requests: [CloudGraphQuery] = []
        var displays = 0
        var renderTimes: [Double] = []
        let loader = CloudGraphLoader(load: { query in
            requests.append(query)
            return try Self.response(query)
        }, changed: { viewport, preserving in
            let began = CACurrentMediaTime()
            let models = variants.compactMap { CloudGraphAdapter.model(viewport: viewport, variant: $0, settings: settings) }
            controller.setChartViewData(from: models, settings: settings, preservingViewport: preserving)
            controller.view.layoutIfNeeded()
            let charts: [CardsGraphInternalView] = Self.descendants(controller.view)
            for chart in charts {
                let renderer = UIGraphicsImageRenderer(size: chart.bounds.size)
                _ = renderer.image { _ in chart.draw(chart.bounds) }
            }
            renderTimes.append((CACurrentMediaTime() - began) * 1000)
            XCTAssertEqual(charts.count, 3)
            for model in models { XCTAssertLessThanOrEqual(model.chartData?.entryCount ?? 0, 3000) }
            displays += 1
            switch displays {
            case 1: initial.fulfill()
            case 2: detail.fulfill()
            case 3: pan.fulfill()
            case 4: short.fulfill()
            default: XCTFail("Unexpected repeated data replacement")
            }
        }, failed: { error, _ in XCTFail("Synthetic graph failed: \(error)") }, isVisible: { true })
        defer { loader.stop(clear: true) }
        output.loader = loader
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 1095 * 24)
        await fulfillment(of: [initial], timeout: 10)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].until - requests[0].since, 1095 * 86400)
        let timeline = try XCTUnwrap(loader.viewport?.timeline)
        let start = Double(timeline.until - 86400)
        loader.setInteraction(active: true)
        for index in 0..<100 { loader.move(to: (start - Double(index))...(start + 3600 - Double(index))) }
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(requests.count, 1, "No network request while the gesture is active")
        loader.setInteraction(active: false)
        await fulfillment(of: [detail], timeout: 10)
        XCTAssertEqual(requests.count, 2, "All plots share one settled detail request")
        XCTAssertEqual(loader.viewport?.timeline, timeline)
        loader.move(to: (start - 7200)...(start - 3600))
        await fulfillment(of: [pan], timeout: 10)
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(loader.viewport?.timeline, timeline)
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 1)
        await fulfillment(of: [short], timeout: 10)
        XCTAssertEqual(requests.last!.until - requests.last!.since, 3600)
        XCTAssertNil(loader.viewport?.detail)
        print("Synthetic simulator graph model/layout/draw milliseconds: \(renderTimes)")
    }

    func testStoppedAndReplacedRequestsCannotPublishEvenIfTransportIgnoresCancellation() async throws {
        let source = ControlledGraphSource()
        let began = expectation(description: "initial request")
        let updated = expectation(description: "new sensor")
        source.started = { _ in began.fulfill() }
        var sensors: [String] = []
        let loader = CloudGraphLoader(load: { try await source.load($0) }, changed: { viewport, _ in
            sensors.append(viewport.overview.sensor)
            updated.fulfill()
        }, failed: { _, _ in XCTFail("Cancelled request reported as failure") }, isVisible: { true })
        defer { loader.stop(clear: true) }
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 24)
        await fulfillment(of: [began], timeout: 2)
        let next = expectation(description: "replacement request")
        source.started = { _ in next.fulfill() }
        loader.start(sensor: "11:22:33:44:55:66", hours: 24)
        await fulfillment(of: [next], timeout: 2)
        try source.finish(1)
        await fulfillment(of: [updated], timeout: 2)
        try source.finish(0)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(sensors, ["11:22:33:44:55:66"])
    }

    func testLongAxisHasBoundedLabelsAndDetailPreservesZoomMatrix() throws {
        let settings = RuuviLocalSettingsUserDefaults()
        let output = GraphTestOutput()
        let controller = CardsGraphViewController(output: output, settings: settings)
        controller.measurementService = RuuviServiceMeasurementImpl(settings: settings,
                                                                  emptyValueString: "—", percentString: "%")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 440, height: 956))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        controller.view.frame = window.bounds
        let variant = MeasurementDisplayVariant(type: .temperature)
        controller.createChartViews(from: [variant])
        let query = try CloudGraphQuery(sensors: ["AA:BB:CC:DD:EE:FF"], since: 1_600_000_000,
                                       until: 1_600_000_000 + 1095 * 86400)
        var viewport = CloudGraphViewport(overview: try XCTUnwrap(Self.response(query).series.first))
        let model = try XCTUnwrap(CloudGraphAdapter.model(viewport: viewport, variant: variant, settings: settings))
        controller.setChartViewData(from: [model], settings: settings, preservingViewport: false)
        controller.view.layoutIfNeeded()
        let charts: [CardsGraphInternalView] = Self.descendants(controller.view)
        let chart = try XCTUnwrap(charts.first)
        chart.xAxisRenderer.computeAxis(min: Double(query.since), max: Double(query.until), inverted: false)
        XCTAssertLessThanOrEqual(chart.xAxis.entries.count, 14)
        chart.zoom(scaleX: 1095, scaleY: 1, x: 200, y: 120)
        let matrix = chart.viewPortHandler.touchMatrix
        let request = try XCTUnwrap(viewport.move(to: Double(query.since + 1000)...Double(query.since + 4600)))
        let detailQuery = try CloudGraphQuery(sensors: query.sensors, since: request.window.since, until: request.window.until)
        XCTAssertTrue(viewport.accept(try XCTUnwrap(Self.response(detailQuery).series.first), for: request))
        let detail = try XCTUnwrap(CloudGraphAdapter.model(viewport: viewport, variant: variant, settings: settings))
        controller.setChartViewData(from: [detail], settings: settings, preservingViewport: true)
        XCTAssertEqual(chart.viewPortHandler.touchMatrix, matrix)
        XCTAssertEqual(chart.xAxis.axisMinimum, Double(query.since))
        XCTAssertEqual(chart.xAxis.axisMaximum, Double(query.until))
    }

    func testOnlySelectedMetricsLoadAndHistoricalWindowsAreNotPolled() async throws {
        let overview = expectation(description: "overview")
        let detail = expectation(description: "detail")
        var requests: [CloudGraphQuery] = []
        var displays = 0
        let loader = CloudGraphLoader(load: { query in
            requests.append(query)
            return try Self.response(query)
        }, changed: { _, _ in
            displays += 1
            if displays == 1 { overview.fulfill() }
            if displays == 2 { detail.fulfill() }
        }, failed: { error, _ in XCTFail("Unexpected error: \(error)") }, isVisible: { true })
        defer { loader.stop(clear: true) }
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 24, metrics: [.temperature, .temperature])
        await fulfillment(of: [overview], timeout: 2)
        XCTAssertEqual(requests.first?.metrics, [.temperature])
        let since = Double(try XCTUnwrap(requests.first).since)
        loader.setInteraction(active: true)
        loader.move(to: (since + 60)...(since + 3600))
        loader.setInteraction(active: false)
        await fulfillment(of: [detail], timeout: 2)
        loader.setInteraction(active: true)
        loader.setInteraction(active: false)
        loader.refresh()
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(requests.count, 2, "Unchanged gestures and old windows must not cause fresh reads")
    }

    func testUnauthorizedRefreshClearsTheRetainedOverviewAndDetail() async throws {
        let overview = expectation(description: "overview")
        let rejected = expectation(description: "access removed")
        var requests = 0
        let loader = CloudGraphLoader(load: { query in
            requests += 1
            if requests > 1 { throw CloudGraphError.unauthorized }
            return try Self.response(query)
        }, changed: { _, _ in overview.fulfill() }, failed: { _, lostAccess in
            XCTAssertTrue(lostAccess)
            rejected.fulfill()
        }, isVisible: { true })
        defer { loader.stop(clear: true) }
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 24)
        await fulfillment(of: [overview], timeout: 2)
        loader.refresh()
        await fulfillment(of: [rejected], timeout: 2)
        XCTAssertNil(loader.viewport)
    }

    func testRetryAfterDelaysManualRefreshWithoutStartingParallelRequests() async throws {
        let rejected = expectation(description: "server busy")
        let recovered = expectation(description: "retry completed")
        var requests = 0
        var failureTime = 0.0
        let loader = CloudGraphLoader(load: { query in
            requests += 1
            if requests == 1 {
                failureTime = CACurrentMediaTime()
                throw CloudGraphError.http(status: 429, retryAfter: 0.4)
            }
            XCTAssertGreaterThanOrEqual(CACurrentMediaTime() - failureTime, 0.35)
            return try Self.response(query)
        }, changed: { _, _ in recovered.fulfill() }, failed: { _, lostAccess in
            XCTAssertFalse(lostAccess)
            rejected.fulfill()
        }, isVisible: { true })
        defer { loader.stop(clear: true) }
        loader.start(sensor: "AA:BB:CC:DD:EE:FF", hours: 24)
        await fulfillment(of: [rejected], timeout: 2)
        loader.refresh()
        loader.refresh()
        await fulfillment(of: [recovered], timeout: 3)
        XCTAssertEqual(requests, 2)
    }

    fileprivate static func response(_ query: CloudGraphQuery) throws -> CloudGraphResponse {
        let resolution = max(1, (query.until - query.since) / 1000)
        let points = (0..<1000).map { index -> [String: Any] in
            let metrics = ["temperature": 20.0, "humidity": 40.0, "pressure": 100000.0].filter {
                query.metrics.map(\.rawValue).contains($0.key)
            }.mapValues { base in
                ["mean": base + sin(Double(index) / 20), "min": base - 1, "max": base + 1, "count": 5]
            }
            return ["timestamp": query.since + Int64(index) * resolution, "metrics": metrics]
        }
        let data = try JSONSerialization.data(withJSONObject: ["series": [[
            "sensor": query.sensors[0], "name": "Synthetic", "since": query.since, "until": query.until,
            "resolutionSeconds": resolution, "offsetTemperature": 0, "offsetHumidity": 0, "offsetPressure": 0,
            "points": points,
        ],], "maxPoints": 1500, "targetPoints": 1000,])
        let response = try JSONDecoder().decode(CloudGraphResponse.self, from: data)
        try query.validate(response)
        return response
    }

    private static func descendants<T: UIView>(_ root: UIView) -> [T] {
        root.subviews.flatMap { view in (view as? T).map { [$0] } ?? descendants(view) }
    }
}

@MainActor
private final class ControlledGraphSource {
    var started: ((CloudGraphQuery) -> Void)?
    var requests: [(CloudGraphQuery, CheckedContinuation<CloudGraphResponse, Error>)] = []
    func load(_ query: CloudGraphQuery) async throws -> CloudGraphResponse {
        try await withCheckedThrowingContinuation { continuation in
            requests.append((query, continuation))
            started?(query)
        }
    }
    func finish(_ index: Int) throws {
        let (query, continuation) = requests[index]
        continuation.resume(returning: try CloudGraphIntegrationTests.response(query))
    }
}

private final class GraphTestOutput: CardsGraphViewOutput {
    weak var loader: CloudGraphLoader?
    func viewDidChangeGraphViewport(_ range: ClosedRange<Double>) { loader?.move(to: range) }
    func viewDidChangeGraphInteraction(active: Bool) { loader?.setInteraction(active: active) }
    func viewDidLoad() { }
    func viewWillAppear() { }
    func viewDidTransition() { }
    func viewDidStartScrolling() { }
    func viewDidEndScrolling() { }
    func viewDidTriggerSync(for snapshot: RuuviTagCardSnapshot?) { }
    func viewDidStartSync(for snapshot: RuuviTagCardSnapshot?) { }
    func viewDidTriggerDoNotShowSyncDialog() { }
    func viewDidAskGraphLongPressTutorialDialog() { }
    func viewDidTriggerDoNotShowGraphLongPressTutorialDialog() { }
    func viewDidTriggerStopSync(for snapshot: RuuviTagCardSnapshot?) { }
    func viewDidTriggerClear(for snapshot: RuuviTagCardSnapshot?) { }
    func viewDidConfirmToClear(for snapshot: RuuviTagCardSnapshot?) { }
    func viewDidConfirmAbortSync(source: GraphHistoryAbortSyncSource) { }
    func viewDidTapOnExportCSV() { }
    func viewDidTapOnExportXLSX() { }
    func viewDidSelectChartHistoryLength(hours: Int) { }
    func viewDidSelectAllChartHistory() { }
    func viewDidSelectLongerHistory() { }
    func viewDidSelectTriggerChartStat(show: Bool) { }
    func viewDidSelectChartsPerScreen(_ count: Int) { }
}
