import Foundation

/// Keeps one overview and one detail response. No summary data is persisted.
public struct CloudGraphViewport: Sendable {
    public struct Window: Equatable, Sendable {
        public let since: Int64
        public let until: Int64
        public var range: ClosedRange<Double> { Double(since)...Double(until) }
    }

    public struct Request: Equatable, Sendable {
        public let id: UUID
        public let window: Window
    }

    public let overview: CloudGraphSeries
    public private(set) var detail: CloudGraphSeries?
    public private(set) var visible: Window
    public private(set) var pending: Request?
    private var detailWindow: Window?
    public var timeline: Window { Window(since: overview.since, until: overview.until) }
    public var isZoomed: Bool { visible != timeline }

    public init(overview: CloudGraphSeries) {
        self.overview = overview
        visible = Window(since: overview.since, until: overview.until)
    }

    /// Round outwards so fractional chart coordinates cannot omit edge readings.
    /// Returning to the overview invalidates any outstanding detail response.
    public mutating func move(to range: ClosedRange<Double>, force: Bool = false) -> Request? {
        guard range.lowerBound.isFinite, range.upperBound.isFinite else { return nil }
        let lower = max(Double(overview.since), range.lowerBound)
        let upper = min(Double(overview.until), range.upperBound)
        guard lower < upper else { return nil }
        let window = Window(since: Int64(floor(lower)), until: Int64(ceil(upper)))
        if !force, visible == window, pending != nil { return nil }
        visible = window
        pending = nil
        if window == timeline {
            detail = nil
            detailWindow = nil
            return nil
        }
        if !force, detail != nil, detailWindow == window { return nil }
        let request = Request(id: UUID(), window: window)
        pending = request
        return request
    }

    @discardableResult
    public mutating func accept(_ series: CloudGraphSeries, for request: Request) -> Bool {
        guard pending == request, series.sensor == overview.sensor,
              series.since >= request.window.since, series.since <= request.window.until,
              series.until >= series.since, series.until <= request.window.until else { return false }
        detail = series
        detailWindow = request.window
        pending = nil
        return true
    }

    public mutating func fail(_ request: Request) {
        if pending == request { pending = nil }
    }

    // Drop whole overview buckets that intersect the detail window. Keeping part of
    // their aggregate would double count observations or invent finer measurements.
    private var displaySeries: [CloudGraphSeries] {
        guard let detail else { return [overview] }
        let points = overview.points.filter {
            $0.timestamp + overview.resolutionSeconds <= detail.since || $0.timestamp > detail.until
        }
        let outside = CloudGraphSeries(
            sensor: overview.sensor, name: overview.name, since: overview.since, until: overview.until,
            resolutionSeconds: overview.resolutionSeconds,
            offsetTemperature: overview.offsetTemperature, offsetHumidity: overview.offsetHumidity,
            offsetPressure: overview.offsetPressure, points: points
        )
        return [outside, detail]
    }

    public func segments(_ metric: CloudGraphMetricName) -> [[CloudGraphSample]] {
        displaySeries.flatMap { series in
            let samples = series.samples(metric)
            let groups = Dictionary(grouping: samples, by: \.segment)
            return groups.keys.sorted().map { groups[$0]! }
        }.sorted { ($0.first?.timestamp ?? 0) < ($1.first?.timestamp ?? 0) }
    }

    public func hasMetric(_ metric: CloudGraphMetricName) -> Bool {
        !overview.samples(metric).isEmpty || !(detail?.samples(metric).isEmpty ?? true)
    }

    public func statistics(_ metric: CloudGraphMetricName, in range: ClosedRange<Double>) -> CloudGraphStatistics? {
        var minimum: Double?
        var maximum: Double?
        var weightedSum = 0.0
        var count = 0.0
        for series in displaySeries {
            let offset = series.offset(metric)
            for point in series.points {
                let start = max(Double(series.since), Double(point.timestamp))
                let end = min(Double(series.until) + 1, Double(point.timestamp + series.resolutionSeconds))
                guard start <= range.upperBound, end > range.lowerBound,
                      let value = point.metrics[metric.rawValue], value.count > 0 else { continue }
                if let low = value.min { minimum = min(minimum ?? .infinity, low + offset) }
                if let high = value.max { maximum = max(maximum ?? -.infinity, high + offset) }
                if let mean = value.mean {
                    weightedSum += (mean + offset) * Double(value.count)
                    count += Double(value.count)
                }
            }
        }
        guard let minimum, let maximum else { return nil }
        return CloudGraphStatistics(min: minimum, max: maximum,
                                     mean: count > 0 && !metric.isCounter ? weightedSum / count : nil)
    }
}
