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

    public static func plan(missing: [RuuviHistoryRange], selected: RuuviHistoryRange,
                            now: Date = Date()) -> [Self] {
        let limit = selected.end.timeIntervalSince(selected.start) >= 90 * 86400 ? 144_000 : 5000
        // Cloud dense data lasts 24 hours. Keep a 48-hour recent window so mixed
        // requests contain only a small sparse prefix, even while the download runs.
        // Never combine a paginated archive query with the latest dense readings:
        // the cloud currently discards DynamoDB's continuation key in mixed mode.
        let split = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970 - 48 * 3600))
        return missing.flatMap { range -> [Self] in
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

public struct RuuviHistoryPoint: Equatable {
    public let timestamp: Double
    public let value: Double
    public let segment: Int
}

public struct RuuviHistoryStatistics {
    public let count: Int
    public let minimum: Double
    public let maximum: Double
    public let average: Double
    public let latest: Double
}

public struct RuuviHistorySeries {
    public let points: [RuuviHistoryPoint]
    public let statistics: RuuviHistoryStatistics?
}

/// Android-compatible extrema sampling. Statistics use all valid readings, before sampling.
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

    public init(range: RuuviHistoryRange) { self.range = range }

    public func add(date: Date, value: Double?) {
        guard let value, value.isFinite, range.contains(date) else { return }
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite, last == nil || timestamp >= last!.timestamp else { return }
        let segment = (last?.segment ?? 0) + ((last.map { timestamp - $0.timestamp > 3600 } ?? false) ? 1 : 0)
        let point = RuuviHistoryPoint(timestamp: timestamp, value: value, segment: segment)
        if first == nil { first = point }
        if let previous = last { area += (timestamp - previous.timestamp) * (previous.value + value) / 2 }
        last = point
        count += 1
        minimum = min(minimum, value)
        maximum = max(maximum, value)
        if count <= Self.maximumPoints { small.append(point) } else { small.removeAll(keepingCapacity: true) }
        let fraction = date.timeIntervalSince(range.start) / range.end.timeIntervalSince(range.start)
        let bucket = min(Self.bucketCount - 1, max(0, Int(fraction * Double(Self.bucketCount))))
        if minima[bucket] == nil || value < minima[bucket]!.value { minima[bucket] = point }
        if maxima[bucket] == nil || value > maxima[bucket]!.value { maxima[bucket] = point }
    }

    public func finish() -> RuuviHistorySeries {
        guard let first, let last else { return RuuviHistorySeries(points: [], statistics: nil) }
        var points = small
        if count > Self.maximumPoints {
            let candidates = ([first, last] + minima.compactMap { $0 } + maxima.compactMap { $0 })
                .sorted { $0.timestamp < $1.timestamp }
            points = []
            for point in candidates where points.last != point {
                points.append(point)
            }
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
