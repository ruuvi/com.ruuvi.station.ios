import Foundation

/// All history intervals are half open: start <= timestamp < end.
public struct RuuviHistoryRange: Hashable, Codable {
    public static let retentionDays = 3 * 365
    public static let retentionHours = retentionDays * 24
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        // Match Android's millisecond intervals and make SQLite round trips exact.
        // Sub-millisecond differences must not become apparent holes in cloud coverage.
        let start = Date(timeIntervalSince1970: (start.timeIntervalSince1970 * 1000).rounded() / 1000)
        let end = Date(timeIntervalSince1970: (end.timeIntervalSince1970 * 1000).rounded() / 1000)
        self.start = start
        self.end = max(start, end)
    }

    public var isEmpty: Bool { start >= end }
    public func contains(_ date: Date) -> Bool { date >= start && date < end }
    public func intersection(_ other: Self) -> Self {
        Self(start: max(start, other.start), end: min(end, other.end))
    }

    public static func retained(now: Date = Date()) -> Self {
        Self(start: now.addingTimeInterval(-Double(retentionHours) * 3600), end: now)
    }

    /// Old downloaded intervals remain reusable. Only the recent tail is
    /// revalidated on opening; live polling overlaps the newest minute.
    public func historyToFetch(coverage: [Self], revalidate: Bool, now: Date = Date()) -> [Self] {
        let cutoff = now.addingTimeInterval(revalidate ? -48 * 3600 : -60)
        let reusable = Self(start: start, end: min(end, cutoff))
        return uncovered(by: coverage.map { $0.intersection(reusable) })
    }

    public func uncovered(by coverage: [Self]) -> [Self] {
        var cursor = start
        var missing: [Self] = []
        for covered in coverage.sorted(by: { $0.start < $1.start }) {
            let clipped = intersection(covered)
            guard !clipped.isEmpty, clipped.end > cursor else { continue }
            if clipped.start > cursor { missing.append(Self(start: cursor, end: clipped.start)) }
            cursor = max(cursor, clipped.end)
        }
        if cursor < end { missing.append(Self(start: cursor, end: end)) }
        return missing
    }

    /// Fixed UTC boundaries keep the archive reusable as a rolling window advances.
    /// Only the clipped first and last intervals change between refreshes.
    public func tiles() -> [Self] {
        guard !isEmpty else { return [] }
        let duration = end.timeIntervalSince(start)
        let step = 3600 * pow(2, max(0, ceil(log2(duration / (32 * 3600)))))
        var result: [Self] = []
        func append(_ interval: Self, step: Double) {
            guard !interval.isEmpty else { return }
            var cursor = floor(interval.start.timeIntervalSince1970 / step) * step
            while cursor < interval.end.timeIntervalSince1970 {
                result.append(interval.intersection(Self(start: Date(timeIntervalSince1970: cursor),
                                                          end: Date(timeIntervalSince1970: cursor + step))))
                cursor += step
            }
        }
        if step <= 21600 { append(self, step: step); return result }
        let archiveStart = Date(timeIntervalSince1970: ceil(start.timeIntervalSince1970 / 86400) * 86400)
        let archiveEnd = Date(timeIntervalSince1970: floor(end.timeIntervalSince1970 / 86400) * 86400 - 86400)
        if archiveStart >= archiveEnd { append(self, step: 21600) }
        else {
            append(Self(start: start, end: archiveStart), step: 21600)
            append(Self(start: archiveStart, end: archiveEnd), step: step)
            append(Self(start: archiveEnd, end: end), step: 21600)
        }
        return result
    }
}

/// Keep the requested limit for the entire download, including its final short page.
public struct RuuviHistoryRequest {
    public enum Mode: String { case sparse, mixed }
    public let range: RuuviHistoryRange
    public let mode: Mode
    public let limit: Int

    public init(range: RuuviHistoryRange, mode: Mode, limit: Int) {
        self.range = range
        self.mode = mode
        self.limit = limit
    }

    public func continuing(from cursor: Date) -> Self? {
        guard cursor > range.start, cursor < range.end else { return nil }
        return Self(range: RuuviHistoryRange(start: cursor, end: range.end), mode: mode, limit: limit)
    }

    public static func plan(missing: [RuuviHistoryRange], selected _: RuuviHistoryRange,
                            now: Date = Date()) -> [Self] {
        // Bound decoding memory and writer occupancy even for multi-year downloads.
        let limit = 5000
        // Cloud dense data lasts 24 hours. Keep a 48-hour recent window so mixed
        // requests contain only a small sparse prefix, even while the download runs.
        // Never combine a paginated archive query with the latest dense readings:
        // the cloud currently discards DynamoDB's continuation key in mixed mode.
        let split = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 - 48 * 3600))
        let requests = missing.flatMap { range -> [Self] in
            var requests: [Self] = []
            if range.start < split {
                requests.append(Self(range: RuuviHistoryRange(start: range.start, end: min(split, range.end)),
                                     mode: .sparse, limit: limit))
            }
            if range.end > split {
                requests.append(Self(range: RuuviHistoryRange(start: max(split, range.start), end: range.end),
                                     mode: .mixed, limit: limit))
            }
            return requests.filter { !$0.range.isEmpty }
        }
        // Fill the recent graph first, then backfill older missing intervals.
        // Each interval still paginates independently in ascending timestamp order.
        return requests.sorted { $0.range.end > $1.range.end }
    }
}

public enum RuuviHistoryPageError: Error { case nonAdvancingResponse }

public extension RuuviHistoryRange {
    /// The cloud endpoint accepts inclusive whole-second bounds.
    var cloudBounds: (since: Double, until: Double) {
        (floor(start.timeIntervalSince1970), ceil(end.timeIntervalSince1970) - 1)
    }

    func nextCloudCursor(timestamps: [Double], responseIsEmpty: Bool) throws -> Date {
        let bounds = cloudBounds
        let valid = timestamps.filter { $0.isFinite && $0 >= bounds.since && $0 <= bounds.until }
        guard responseIsEmpty || !valid.isEmpty else { throw RuuviHistoryPageError.nonAdvancingResponse }
        let next = valid.max().map { min(end, Date(timeIntervalSince1970: $0 + 1)) } ?? end
        guard next > start else { throw RuuviHistoryPageError.nonAdvancingResponse }
        return next
    }
}

public enum RuuviHistorySelection: Equatable {
    case rolling(hours: Int)
    case custom(start: Date, end: Date)

    public func resolve(now: Date = Date(), calendar: Calendar = .current) -> RuuviHistoryRange {
        let range: RuuviHistoryRange
        switch self {
        case let .rolling(hours):
            let length = hours <= 0 ? RuuviHistoryRange.retentionHours : min(hours, RuuviHistoryRange.retentionHours)
            range = RuuviHistoryRange(start: now.addingTimeInterval(-Double(length) * 3600), end: now)
        case let .custom(start, end):
            let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
            range = RuuviHistoryRange(start: calendar.startOfDay(for: start), end: exclusiveEnd)
        }
        return range.intersection(.retained(now: now))
    }
}

/// Shared by database scans and cloud jobs. Cancellation prevents subsequent pages and writes.
public final class RuuviHistoryCancellation {
    private let lock = NSLock()
    private var cancelled = false
    private var cancellationHandler: (() -> Void)?
    public init() {}
    public var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    public func cancel() {
        lock.lock()
        cancelled = true
        let handler = cancellationHandler
        cancellationHandler = nil
        lock.unlock()
        handler?()
    }

    public func setCancellationHandler(_ handler: (() -> Void)?) {
        lock.lock()
        let alreadyCancelled = cancelled
        cancellationHandler = alreadyCancelled ? nil : handler
        lock.unlock()
        if alreadyCancelled { handler?() }
    }
}

public struct RuuviHistoryPoint: Hashable {
    public let timestamp: Double
    public let value: Double
    public let segment: Int
}

public struct RuuviHistoryStatistics: Equatable {
    public let count: Int
    public let minimum: Double
    public let maximum: Double
    public let average: Double
    public let latest: Double
}

public struct RuuviHistorySeries: Equatable {
    public let points: [RuuviHistoryPoint]
    public let statistics: RuuviHistoryStatistics?

    /// Intervals must be disjoint. Statistics are merged from raw-reading summaries,
    /// never recalculated from the sampled display points.
    public static func merging(_ series: [Self], range: RuuviHistoryRange) -> Self {
        let ordered = series.filter { !$0.points.isEmpty }.sorted { $0.points[0].timestamp < $1.points[0].timestamp }
        let sampler = RuuviHistorySampler(range: range)
        var count = 0
        var minimum = Double.infinity, maximum = -Double.infinity, area = 0.0
        var first: RuuviHistoryPoint?, last: RuuviHistoryPoint?
        for item in ordered {
            guard let a = item.points.first, let b = item.points.last, let stats = item.statistics else { continue }
            let segment = (last?.segment ?? 0) + ((last.map { a.timestamp - $0.timestamp > 3600 } ?? false) ? 1 : 0)
            if let previous = last { area += (a.timestamp - previous.timestamp) * (previous.value + a.value) / 2 }
            area += stats.average * (b.timestamp - a.timestamp)
            count += stats.count
            minimum = min(minimum, stats.minimum)
            maximum = max(maximum, stats.maximum)
            for point in item.points {
                sampler.add(date: Date(timeIntervalSince1970: point.timestamp), value: point.value,
                            segment: point.segment - a.segment + segment)
            }
            if first == nil { first = a }
            last = RuuviHistoryPoint(timestamp: b.timestamp, value: b.value, segment: b.segment - a.segment + segment)
        }
        guard let first, let last else { return sampler.finish() }
        let duration = last.timestamp - first.timestamp
        return Self(points: sampler.finish().points, statistics: RuuviHistoryStatistics(
            count: count, minimum: minimum, maximum: maximum,
            average: duration > 0 ? area / duration : last.value, latest: last.value
        ))
    }
}

/// Bounded extrema sampling. Statistics use all valid readings, before sampling.
public final class RuuviHistorySampler {
    public static let maximumPoints = 400
    private static let bucketCount = (maximumPoints - 2) / 2
    private let range: RuuviHistoryRange
    private var small: [RuuviHistoryPoint] = []
    private var minima = [RuuviHistoryPoint?](repeating: nil, count: bucketCount)
    private var maxima = [RuuviHistoryPoint?](repeating: nil, count: bucketCount)
    private var first: RuuviHistoryPoint?
    private var last: RuuviHistoryPoint?
    private var count = 0
    private var minimum = Double.infinity
    private var maximum = -Double.infinity
    private var area = 0.0
    private var segmentStarts: [RuuviHistoryPoint] = []

    public init(range: RuuviHistoryRange) { self.range = range }

    public func add(date: Date, value: Double?) {
        add(date: date, value: value, segment: nil)
    }

    fileprivate func add(date: Date, value: Double?, segment suppliedSegment: Int?) {
        guard let value, value.isFinite, range.contains(date) else { return }
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite, last == nil || timestamp >= last!.timestamp else { return }
        let segment = suppliedSegment ?? ((last?.segment ?? 0) + ((last.map { timestamp - $0.timestamp > 3600 } ?? false) ? 1 : 0))
        let point = RuuviHistoryPoint(timestamp: timestamp, value: value, segment: segment)
        if last?.segment != segment, segmentStarts.count < Self.maximumPoints - 4 { segmentStarts.append(point) }
        if first == nil { first = point }
        if let previous = last { area += (timestamp - previous.timestamp) * (previous.value + value) / 2 }
        last = point
        count += 1
        minimum = min(minimum, value)
        maximum = max(maximum, value)
        if count <= Self.maximumPoints { small.append(point) } else if !small.isEmpty { small.removeAll(keepingCapacity: true) }
        let fraction = date.timeIntervalSince(range.start) / range.end.timeIntervalSince(range.start)
        let bucket = min(Self.bucketCount - 1, max(0, Int(fraction * Double(Self.bucketCount))))
        if minima[bucket] == nil || value < minima[bucket]!.value { minima[bucket] = point }
        if maxima[bucket] == nil || value > maxima[bucket]!.value { maxima[bucket] = point }
    }

    public func finish() -> RuuviHistorySeries {
        guard let first, let last else { return RuuviHistorySeries(points: [], statistics: nil) }
        var points = small
        if count > Self.maximumPoints {
            let extrema = minima.compactMap { $0 } + maxima.compactMap { $0 }
            // Reserve a representative for each gap-delimited segment when it fits
            // the display budget. Otherwise an isolated reading can vanish entirely.
            let required = [first, last] + [extrema.min { $0.value < $1.value }, extrema.max { $0.value < $1.value }].compactMap { $0 } + segmentStarts
            var unique: [RuuviHistoryPoint] = []
            var seen = Set<RuuviHistoryPoint>()
            for point in required where seen.insert(point).inserted { unique.append(point) }
            var remaining: [RuuviHistoryPoint] = []
            for point in extrema where seen.insert(point).inserted { remaining.append(point) }
            remaining.sort { $0.timestamp < $1.timestamp }
            let capacity = Self.maximumPoints - unique.count
            if remaining.count <= capacity { unique += remaining }
            else if capacity > 0 {
                for index in 0..<capacity { unique.append(remaining[index * remaining.count / capacity]) }
            }
            points = unique.sorted { $0.timestamp < $1.timestamp }
        }
        let duration = last.timestamp - first.timestamp
        return RuuviHistorySeries(points: points, statistics: RuuviHistoryStatistics(
            count: count, minimum: minimum, maximum: maximum,
            average: duration > 0 ? area / duration : last.value, latest: last.value
        ))
    }
}

public struct RuuviHistoryCoverage {
    public let ranges: [RuuviHistoryRange]
    public let generation: Int
    public init(ranges: [RuuviHistoryRange], generation: Int) {
        self.ranges = ranges
        self.generation = generation
    }
}
