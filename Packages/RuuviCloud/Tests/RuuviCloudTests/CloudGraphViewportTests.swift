import XCTest
@testable import RuuviCloud

final class CloudGraphViewportTests: XCTestCase {
    private func series(since: Int64 = 100, until: Int64 = 200, resolution: Int64 = 10,
                        samples: [(Int64, Double, Int64)] = [(100, 90, 10), (110, 90, 10), (120, 90, 10), (130, 90, 10)]) -> CloudGraphSeries {
        CloudGraphSeries(sensor: "AA:BB:CC:DD:EE:FF", name: "Test", since: since, until: until,
                          resolutionSeconds: resolution, offsetTemperature: 1, offsetHumidity: 0, offsetPressure: 0,
                          points: samples.map { time, value, count in
            CloudGraphPoint(timestamp: time, metrics: ["temperature": CloudGraphMetric(
                mean: value, min: value - 1, max: value + 1, count: count, last: nil),])
        })
    }

    func testZoomRoundsOutwardsAndKeepsFullTimeline() throws {
        var viewport = CloudGraphViewport(overview: series(since: 100, until: 63_072_100))
        let request = try XCTUnwrap(viewport.move(to: 123.7...345.1))
        XCTAssertEqual(request.window.since, 123)
        XCTAssertEqual(request.window.until, 346)
        XCTAssertEqual(viewport.timeline.until, 63_072_100)
        XCTAssertTrue(viewport.isZoomed)
        XCTAssertNil(viewport.move(to: 123.7...345.1), "Repeated gesture coordinates must coalesce")
        XCTAssertEqual(viewport.pending, request)
    }

    func testLateResponseCannotReplaceNewPanOrOverview() throws {
        var viewport = CloudGraphViewport(overview: series())
        let first = try XCTUnwrap(viewport.move(to: 110...130))
        let second = try XCTUnwrap(viewport.move(to: 130...150))
        XCTAssertFalse(viewport.accept(series(since: 110, until: 130), for: first))
        XCTAssertTrue(viewport.accept(series(since: 130, until: 150), for: second))
        let third = try XCTUnwrap(viewport.move(to: 150...170))
        XCTAssertNil(viewport.move(to: 99...201))
        XCTAssertNil(viewport.pending)
        XCTAssertNil(viewport.detail)
        XCTAssertFalse(viewport.accept(series(since: 150, until: 170), for: third))
        XCTAssertFalse(viewport.isZoomed)
    }

    func testDetailReplacesOverlappingBucketsAndUsesTheirOwnCounts() throws {
        var viewport = CloudGraphViewport(overview: series())
        let request = try XCTUnwrap(viewport.move(to: 111...129))
        XCTAssertTrue(viewport.accept(series(since: 111, until: 129, resolution: 2,
                                             samples: [(110, 10, 1), (112, 20, 3)]), for: request))
        let samples = viewport.segments(.temperature).flatMap { $0 }
        XCTAssertEqual(samples.map(\.timestamp).sorted(), [100, 111, 112, 130])
        XCTAssertFalse(samples.contains { $0.timestamp == 120 }, "Coarse values must not survive inside detail")
        let stats = try XCTUnwrap(viewport.statistics(.temperature, in: 111...129))
        XCTAssertEqual(stats.min, 10)
        XCTAssertEqual(stats.max, 22)
        XCTAssertEqual(try XCTUnwrap(stats.mean), 18.5, accuracy: 0.0001)
        XCTAssertEqual(viewport.segments(.temperature).count, 3, "Do not draw lines between overview and detail")
    }

    func testEmptyDetailLeavesAGapAndStillAllowsPanning() throws {
        var viewport = CloudGraphViewport(overview: series())
        let request = try XCTUnwrap(viewport.move(to: 111...129))
        XCTAssertTrue(viewport.accept(series(since: 111, until: 129, resolution: 1, samples: []), for: request))
        XCTAssertNil(viewport.statistics(.temperature, in: 111...129))
        XCTAssertEqual(viewport.segments(.temperature).flatMap { $0 }.map(\.timestamp), [100, 130])
        XCTAssertTrue(viewport.hasMetric(.temperature))
        XCTAssertNotNil(viewport.move(to: 140...160))
    }

    func testRefreshAndRetryDoNotReuseStaleRequests() throws {
        var viewport = CloudGraphViewport(overview: series())
        let first = try XCTUnwrap(viewport.move(to: 110...130))
        XCTAssertTrue(viewport.accept(series(since: 110, until: 130), for: first))
        XCTAssertNil(viewport.move(to: 110...130))
        let refresh = try XCTUnwrap(viewport.move(to: 110...130, force: true))
        XCTAssertNotEqual(first.id, refresh.id)
        viewport.fail(first)
        XCTAssertEqual(viewport.pending, refresh)
        viewport.fail(refresh)
        let retry = try XCTUnwrap(viewport.move(to: 110...130, force: true))
        XCTAssertNotEqual(retry.id, refresh.id)
    }

    func testRetentionClampIsAcceptedWithoutRepeatedRequests() throws {
        var viewport = CloudGraphViewport(overview: series())
        let request = try XCTUnwrap(viewport.move(to: 100...130))
        XCTAssertTrue(viewport.accept(series(since: 102, until: 130), for: request))
        XCTAssertNil(viewport.move(to: 100...130))
        XCTAssertEqual(viewport.detail?.since, 102)
    }
    func testServerClockClampClearsPendingAndAllowsRefresh() throws {
        var viewport = CloudGraphViewport(overview: series())
        let request = try XCTUnwrap(viewport.move(to: 110...190))
        XCTAssertTrue(viewport.accept(series(since: 112, until: 187), for: request))
        XCTAssertNil(viewport.pending)
        XCTAssertNil(viewport.move(to: 110...190))
        XCTAssertEqual(viewport.visible, request.window)
        XCTAssertEqual(viewport.detail?.until, 187)
        XCTAssertNotNil(viewport.move(to: 110...190, force: true))
    }

    func testDetailRejectsOutOfRequestOrReversedBounds() throws {
        var viewport = CloudGraphViewport(overview: series())
        let request = try XCTUnwrap(viewport.move(to: 110...190))
        for (since, until): (Int64, Int64) in [(109, 190), (110, 191), (180, 179)] {
            XCTAssertFalse(viewport.accept(series(since: since, until: until), for: request))
            XCTAssertEqual(viewport.pending, request)
            XCTAssertNil(viewport.detail)
        }
    }

}
