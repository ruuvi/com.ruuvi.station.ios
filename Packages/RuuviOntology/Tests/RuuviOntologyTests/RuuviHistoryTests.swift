@testable import RuuviOntology
import XCTest

final class RuuviHistoryTests: XCTestCase {
    private func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }
    private func range(_ start: Double, _ end: Double) -> RuuviHistoryRange {
        RuuviHistoryRange(start: date(start), end: date(end))
    }

    func testDenseHistoryPreservesActualExtremaAndEndpointsWithin400Points() {
        let sampler = RuuviHistorySampler(range: range(0, 144_000))
        for index in 0 ..< 144_000 {
            let value = index == 70001 ? 999.0 : index == 90001 ? -999.0 : Double(index % 17)
            sampler.add(date: date(Double(index)), value: value)
        }
        let result = sampler.finish()
        XCTAssertLessThanOrEqual(result.points.count, 400)
        XCTAssertEqual(result.points.first?.timestamp, 0)
        XCTAssertEqual(result.points.last?.timestamp, 143_999)
        XCTAssertTrue(result.points.contains { $0.timestamp == 70001 && $0.value == 999 })
        XCTAssertTrue(result.points.contains { $0.timestamp == 90001 && $0.value == -999 })
        XCTAssertEqual(result.statistics?.count, 144_000)
        XCTAssertEqual(result.statistics?.minimum, -999)
        XCTAssertEqual(result.statistics?.maximum, 999)
        XCTAssertEqual(result.points.map(\.timestamp), result.points.map(\.timestamp).sorted())
    }

    func testSamplingContinuous100DaysDoesNotInventGaps() {
        let duration = Double(100 * 24 * 3600)
        let sampler = RuuviHistorySampler(range: range(0, duration))
        for index in 0 ..< (100 * 24 * 4) {
            sampler.add(date: date(Double(index * 900)), value: Double(index % 13))
        }
        let points = sampler.finish().points
        XCTAssertLessThanOrEqual(points.count, 400)
        XCTAssertEqual(Set(points.map(\.segment)), [0])
        XCTAssertTrue(zip(points, points.dropFirst()).contains { $1.timestamp - $0.timestamp > 3600 })
    }

    func testRealGapsAndIsolatedPointsSurviveSampling() {
        let sampler = RuuviHistorySampler(range: range(0, 20000))
        sampler.add(date: date(0), value: 1)
        sampler.add(date: date(3600), value: 2)
        sampler.add(date: date(7201), value: 3)
        sampler.add(date: date(15000), value: 4)
        XCTAssertEqual(sampler.finish().points.map(\.segment), [0, 0, 1, 2])
    }

    func testNilNonfiniteAndExclusiveEndAreExcluded() {
        let sampler = RuuviHistorySampler(range: range(10, 20))
        sampler.add(date: date(9), value: 5)
        sampler.add(date: date(10), value: nil)
        sampler.add(date: date(11), value: .nan)
        sampler.add(date: date(12), value: .infinity)
        sampler.add(date: date(13), value: 1)
        sampler.add(date: date(20), value: 2)
        XCTAssertEqual(sampler.finish().points.count, 1)
        XCTAssertEqual(sampler.finish().statistics?.average, 1)
    }

    func testStatisticsUseTimeWeightingBeforeSampling() {
        let sampler = RuuviHistorySampler(range: range(0, 1001))
        for index in 0 ... 1000 {
            sampler.add(date: date(Double(index)), value: Double(index))
        }
        let result = sampler.finish()
        XCTAssertEqual(result.statistics!.average, 500, accuracy: 0.00001)
        XCTAssertEqual(result.statistics?.count, 1001)
        let uneven = RuuviHistorySampler(range: range(0, 11))
        uneven.add(date: date(0), value: 0)
        uneven.add(date: date(1), value: 10)
        uneven.add(date: date(10), value: 10)
        XCTAssertEqual(uneven.finish().statistics!.average, 9.5, accuracy: 0.00001)
    }

    func testCoverageFindsOnlyMissingRangesIncludingOverlapsAndEmptyFetches() {
        XCTAssertEqual(
            range(0, 100).uncovered(by: [range(20, 40), range(30, 50), range(70, 90)]),
            [range(0, 20), range(50, 70), range(90, 100)]
        )
        XCTAssertEqual(range(0, 100).uncovered(by: [range(-10, 200)]), [])
        XCTAssertEqual(range(0, 100).uncovered(by: [range(0, 50)]), [range(50, 100)])
        XCTAssertEqual(range(0, 0).uncovered(by: []), [])
    }

    func testAllMeansThreeYearsAndRangeClampsToRetention() {
        let now = date(200_000_000)
        XCTAssertEqual(RuuviHistoryRange.retentionDays, 1095)
        XCTAssertEqual(RuuviHistoryRange.retained(now: now).end.timeIntervalSince(
            RuuviHistoryRange.retained(now: now).start
        ), 1095 * 86400)
        XCTAssertEqual(
            RuuviHistorySelection.rolling(hours: 365 * 24).resolve(now: now).start,
            now.addingTimeInterval(-365 * 86400)
        )
        XCTAssertEqual(RuuviHistorySelection.rolling(hours: 0).resolve(now: now), .retained(now: now))
        XCTAssertEqual(RuuviHistorySelection.rolling(hours: 24 * 365 * 4).resolve(now: now), .retained(now: now))
        XCTAssertEqual(RuuviHistorySelection.rolling(hours: 24).resolve(now: now).start, now.addingTimeInterval(-86400))
    }

    func testCustomDatesIncludeWholeLastDayAcrossDST() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let result = RuuviHistorySelection.custom(start: start, end: start).resolve(now: now, calendar: calendar)
        XCTAssertEqual(result.end.timeIntervalSince(result.start), 23 * 3600)
        XCTAssertEqual(calendar.component(.day, from: result.end), 30)
    }

    func testCoverageRoundTripDoesNotInventTinyMissingIntervals() {
        let start = Date(timeIntervalSince1970: 1_790_000_000.123456)
        let requested = RuuviHistoryRange(start: start, end: start.addingTimeInterval(500))
        let saved = RuuviHistoryRange(
            start: Date(timeIntervalSince1970: requested.start.timeIntervalSince1970),
            end: Date(timeIntervalSince1970: requested.end.timeIntervalSince1970)
        )
        XCTAssertEqual(requested, saved)
        XCTAssertTrue(requested.uncovered(by: [saved]).isEmpty)
    }

    func testCancellationCancelsActiveTransportAndFutureHandlersImmediately() {
        let cancellation = RuuviHistoryCancellation()
        var cancellations = 0
        cancellation.setCancellationHandler { cancellations += 1 }
        cancellation.cancel()
        XCTAssertEqual(cancellations, 1)
        cancellation.setCancellationHandler { cancellations += 1 }
        XCTAssertEqual(cancellations, 2)
        cancellation.cancel()
        XCTAssertEqual(cancellations, 2)
    }

    func testCloudBoundsAndPaginationAreHalfOpenLocallyAndInclusiveOnServer() throws {
        let selection = range(10.25, 100.5)
        XCTAssertEqual(selection.cloudBounds.since, 10)
        XCTAssertEqual(selection.cloudBounds.until, 100)
        XCTAssertEqual(try selection.nextCloudCursor(timestamps: [10, 20], responseIsEmpty: false), date(21))
        XCTAssertEqual(try selection.nextCloudCursor(timestamps: [100], responseIsEmpty: false), selection.end)
        XCTAssertEqual(try selection.nextCloudCursor(timestamps: [], responseIsEmpty: true), selection.end)
        XCTAssertEqual(range(10, 100).cloudBounds.until, 99)
    }

    func testCloudPageOutsideRequestedRangeFailsInsteadOfAdvancingCoverage() {
        XCTAssertThrowsError(try range(10, 100).nextCloudCursor(timestamps: [0, 9, 100, .nan], responseIsEmpty: false))
        XCTAssertThrowsError(try range(10, 100).nextCloudCursor(timestamps: [], responseIsEmpty: false))
    }

    func testLongSelectionsKeepEveryPageBoundedIncludingContinuation() throws {
        let now = date(200_000_000)
        for days in [90, 365, 730, 1095] {
            let selected = RuuviHistoryRange(start: now.addingTimeInterval(-Double(days) * 86400), end: now)
            let requests = RuuviHistoryRequest.plan(missing: [selected], selected: selected, now: now)
            XCTAssertEqual(requests.map(\.limit), [5000, 5000])
            XCTAssertEqual(requests.map(\.mode), [.mixed, .sparse])
            let lastArchivePage = try XCTUnwrap(
                requests[1]
                    .continuing(from: requests[1].range.end.addingTimeInterval(-3600))
            )
            XCTAssertEqual(lastArchivePage.limit, 5000)
            XCTAssertEqual(lastArchivePage.mode, .sparse)
            XCTAssertNil(lastArchivePage.continuing(from: lastArchivePage.range.end))
        }
    }

    func testHistoryPlanSplitsWithoutHolesOrOverlaps() {
        let now = date(200_000_000.123)
        let selected = RuuviHistoryRange(start: now.addingTimeInterval(-1095 * 86400), end: now)
        let requests = RuuviHistoryRequest.plan(missing: [selected], selected: selected, now: now).sorted { $0.range.start < $1.range.start }
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.range.start, selected.start)
        XCTAssertEqual(requests.last?.range.end, selected.end)
        XCTAssertEqual(requests[0].range.end, requests[1].range.start)
        XCTAssertEqual(requests[0].range.cloudBounds.until + 1, requests[1].range.cloudBounds.since)
        XCTAssertLessThanOrEqual(requests[1].range.end.timeIntervalSince(requests[1].range.start), 48 * 3600 + 1)
        XCTAssertTrue(selected.uncovered(by: requests.map(\.range)).isEmpty)
    }

    func testHistoryPlanOnlyRequestsMissingIntervalsAndKeepsSmallSelectionLimit() {
        let now = date(200_000_000)
        let selected = RuuviHistoryRange(start: now.addingTimeInterval(-7 * 86400), end: now)
        let missing = [RuuviHistoryRange(start: selected.start, end: selected.start.addingTimeInterval(3600)),
                       RuuviHistoryRange(start: now.addingTimeInterval(-3600), end: now)]
        let requests = RuuviHistoryRequest.plan(missing: missing, selected: selected, now: now)
        XCTAssertEqual(requests.map(\.range), Array(missing.reversed()))
        XCTAssertEqual(requests.map(\.mode), [.mixed, .sparse])
        XCTAssertEqual(requests.map(\.limit), [5000, 5000])
        XCTAssertTrue(RuuviHistoryRequest.plan(missing: [], selected: selected, now: now).isEmpty)
    }

    func testRecentReadingsLoadFirstAndArchiveContinuationStaysInItsInterval() throws {
        let now = date(200_000_000)
        let selected = RuuviHistoryRange(start: now.addingTimeInterval(-1095 * 86400), end: now)
        let requests = RuuviHistoryRequest.plan(missing: [selected], selected: selected, now: now)
        XCTAssertEqual(requests[0].mode, .mixed)
        XCTAssertEqual(requests[0].range.end, selected.end)
        let archive = requests[1]
        // DynamoDB can return far fewer records than requested at its byte limit.
        let timestamps = [archive.range.start.timeIntervalSince1970, archive.range.start.timeIntervalSince1970 + 900]
        let cursor = try archive.range.nextCloudCursor(timestamps: timestamps, responseIsEmpty: false)
        let next = try XCTUnwrap(archive.continuing(from: cursor))
        XCTAssertEqual(next.range.start, date(timestamps[1] + 1))
        XCTAssertEqual(next.range.end, archive.range.end)
        XCTAssertEqual(next.mode, .sparse)
        XCTAssertLessThan(next.range.start, requests[0].range.start)
        let emptyCursor = try next.range.nextCloudCursor(timestamps: [], responseIsEmpty: true)
        XCTAssertEqual(emptyCursor, requests[0].range.start)
        XCTAssertNil(next.continuing(from: emptyCursor))
    }

    func testReopeningThreeYearsReusesArchiveAndOnlyRevalidatesRecentTail() {
        let now = date(200_000_000)
        let selected = RuuviHistoryRange.retained(now: now)
        let missing = selected.historyToFetch(coverage: [selected], revalidate: true, now: now)
        XCTAssertEqual(missing, [RuuviHistoryRange(start: now.addingTimeInterval(-48 * 3600), end: now)])
        let historical = RuuviHistoryRange(start: selected.start, end: now.addingTimeInterval(-90 * 86400))
        XCTAssertTrue(historical.historyToFetch(coverage: [historical], revalidate: true, now: now).isEmpty)
    }

    func testTilesCoverLongAndShortSelectionsWithoutOverlaps() {
        for hours in [1, 48, 240, 2160, RuuviHistoryRange.retentionHours] {
            let selected = range(1_800_012_345, 1_800_012_345 + Double(hours * 3600))
            let tiles = selected.tiles()
            XCTAssertLessThanOrEqual(tiles.count, 45)
            XCTAssertEqual(tiles.first?.start, selected.start)
            XCTAssertEqual(tiles.last?.end, selected.end)
            XCTAssertTrue(selected.uncovered(by: tiles).isEmpty)
            for (a, b) in zip(tiles, tiles.dropFirst()) { XCTAssertEqual(a.end, b.start) }
        }
        XCTAssertTrue(range(0, 0).tiles().isEmpty)
    }

    func testRollingHistoryReusesInteriorTilesAndBoundsBothMovingEdges() {
        let selection = RuuviHistorySelection.rolling(hours: RuuviHistoryRange.retentionHours)
        let before = selection.resolve(now: date(1_800_012_345)).tiles()
        let after = selection.resolve(now: date(1_800_012_405)).tiles()
        let changed = after.filter { !before.contains($0) }
        XCTAssertEqual(changed.count, 2)
        XCTAssertTrue(changed.allSatisfy { $0.end.timeIntervalSince($0.start) <= 21600 })
    }

    func testMergedTilesKeepRawStatisticsExtremaAndDoNotInventGaps() throws {
        let selected = range(0, 1095 * 86400)
        let tiles = selected.tiles()
        let samplers = tiles.map(RuuviHistorySampler.init)
        let raw = RuuviHistorySampler(range: selected)
        var tile = 0
        for index in 0..<(1095 * 96) {
            let timestamp = date(Double(index * 900))
            while !tiles[tile].contains(timestamp) { tile += 1 }
            let value = index == 50001 ? -999.0 : index == 70001 ? 999.0 : Double(index % 17)
            raw.add(date: timestamp, value: value)
            samplers[tile].add(date: timestamp, value: value)
        }
        let merged = RuuviHistorySeries.merging(samplers.reversed().map { $0.finish() }, range: selected)
        let expected = try XCTUnwrap(raw.finish().statistics)
        let actual = try XCTUnwrap(merged.statistics)
        XCTAssertEqual(actual.count, expected.count)
        XCTAssertEqual(actual.minimum, expected.minimum)
        XCTAssertEqual(actual.maximum, expected.maximum)
        XCTAssertEqual(actual.latest, expected.latest)
        XCTAssertEqual(actual.average, expected.average, accuracy: 0.00000001)
        XCTAssertEqual(Set(merged.points.map(\.segment)), [0])
        XCTAssertLessThanOrEqual(merged.points.count, 400)
        XCTAssertTrue(merged.points.contains { $0.value == -999 })
        XCTAssertTrue(merged.points.contains { $0.value == 999 })
    }

    func testDownsamplingRetainsAnIsolatedSegmentInALongRange() {
        let sampler = RuuviHistorySampler(range: range(0, 1095 * 86400))
        for index in 0..<250 { sampler.add(date: date(Double(index * 2)), value: Double(index % 10)) }
        sampler.add(date: date(5000), value: 5)
        for index in 0..<250 { sampler.add(date: date(Double(10000 + index * 2)), value: Double(index % 10)) }
        let result = sampler.finish()
        XCTAssertEqual(Set(result.points.map(\.segment)), [0, 1, 2])
        XCTAssertTrue(result.points.contains { $0.timestamp == 5000 })
        XCTAssertEqual(result.statistics?.count, 501)
        XCTAssertLessThanOrEqual(result.points.count, 400)
    }

    func testMergingSingletonTilesAndRealGapsPreservesTimeWeightedAverage() throws {
        let a = RuuviHistorySampler(range: range(0, 10))
        a.add(date: date(1), value: 0)
        let b = RuuviHistorySampler(range: range(10, 20000))
        b.add(date: date(5000), value: 10)
        b.add(date: date(15000), value: 20)
        let merged = RuuviHistorySeries.merging([b.finish(), a.finish()], range: range(0, 20000))
        XCTAssertEqual(merged.points.map(\.segment), [0, 1, 2])
        XCTAssertEqual(merged.statistics?.count, 3)
        XCTAssertEqual(try XCTUnwrap(merged.statistics?.average), (4999 * 5 + 10000 * 15) / 14999.0, accuracy: 0.00000001)
    }

    func testArchiveReuseStillFetchesHolesAndLivePollingOverlapsOneMinute() {
        let selected = range(0, 1_000_000)
        XCTAssertEqual(
            selected.historyToFetch(
                coverage: [range(0, 100), range(200, 1_000_000)],
                revalidate: false,
                now: date(1_000_000)
            ),
            [range(100, 200), range(999_940, 1_000_000)]
        )
    }
}
