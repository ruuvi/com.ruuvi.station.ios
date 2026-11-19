import Foundation
import RuuviCloud

/// Main-thread coordinator. Retains at most one overview and one visible detail.
/// URLSession and JSON decoding run in the cloud client's nonisolated async path.
final class CloudGraphLoader {
    typealias Load = (CloudGraphQuery) async throws -> CloudGraphResponse
    private let load: Load
    private let changed: (CloudGraphViewport, Bool) -> Void
    private let failed: (Error, Bool) -> Void
    private let isVisible: () -> Bool
    private var sensor: String?
    private var hours = 0
    private var metrics: [CloudGraphMetricName] = []
    private var retryNotBefore: Date?
    private var generation = UUID()
    private var overviewTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var timer: Timer?
    private var interactionActive = false
    private var latestRange: ClosedRange<Double>?
    private var pendingDisplay = false
    private(set) var viewport: CloudGraphViewport?

    init(load: @escaping Load, changed: @escaping (CloudGraphViewport, Bool) -> Void,
         failed: @escaping (Error, Bool) -> Void, isVisible: @escaping () -> Bool) {
        self.load = load
        self.changed = changed
        self.failed = failed
        self.isVisible = isVisible
    }

    deinit {
        overviewTask?.cancel()
        detailTask?.cancel()
        timer?.invalidate()
    }

    func stop(clear: Bool = false) {
        generation = UUID()
        overviewTask?.cancel()
        overviewTask = nil
        detailTask?.cancel()
        detailTask = nil
        timer?.invalidate()
        timer = nil
        interactionActive = false
        pendingDisplay = false
        latestRange = nil
        if clear { viewport = nil; sensor = nil }
    }

    func start(sensor: String, hours: Int, metrics: [CloudGraphMetricName] = CloudGraphMetricName.allCases) {
        let metrics = Set(metrics).sorted { $0.rawValue < $1.rawValue }
        guard self.sensor != sensor || self.hours != hours || self.metrics != metrics || viewport == nil else {
            refresh()
            return
        }
        stop(clear: true)
        self.sensor = sensor
        self.hours = hours
        self.metrics = metrics
        fetchOverview(preservingViewport: false)
    }

    func refresh() {
        guard !interactionActive else { scheduleRefresh(); return }
        if let viewport, viewport.isZoomed {
            // Historical windows are refreshed when visited, not polled each minute.
            guard viewport.visible.until >= Int64(Date().timeIntervalSince1970) - 300 else {
                changed(viewport, true)
                return
            }
            move(to: viewport.visible.range, force: true)
        } else {
            fetchOverview(preservingViewport: viewport != nil)
        }
    }

    func setInteraction(active: Bool) {
        interactionActive = active
        if active {
            detailTask?.cancel()
            detailTask = nil
        } else {
            if let range = latestRange { move(to: range, force: viewport?.pending != nil) }
            if pendingDisplay, let viewport {
                pendingDisplay = false
                changed(viewport, true)
            }
        }
    }

    private func fetchOverview(preservingViewport: Bool) {
        guard overviewTask == nil, let sensor else { return }
        let generation = generation
        let metrics = metrics
        let until = Int64(Date().timeIntervalSince1970)
        let since = max(0, until - Int64(hours) * 3600)
        overviewTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let query = try CloudGraphQuery(sensors: [sensor], since: since, until: until, metrics: metrics)
                try await self.waitForRetryWindow()
                let response = try await self.load(query)
                try Task.checkCancellation()
                guard generation == self.generation, let series = response.series.first else { return }
                self.overviewTask = nil
                // A refresh started before a gesture must not discard the user's detail/zoom.
                if preservingViewport && (self.interactionActive || self.viewport?.isZoomed == true) {
                    self.scheduleRefresh()
                    return
                }
                let viewport = CloudGraphViewport(overview: series)
                self.viewport = viewport
                self.changed(viewport, preservingViewport)
                self.scheduleRefresh()
            } catch {
                guard generation == self.generation, !Task.isCancelled else { return }
                self.overviewTask = nil
                self.handle(error)
            }
        }
    }

    func move(to range: ClosedRange<Double>, force: Bool = false) {
        latestRange = range
        guard var viewport else { return }
        let previous = viewport.pending
        let hadDetail = viewport.detail != nil
        let request = viewport.move(to: range, force: force)
        self.viewport = viewport
        if previous != viewport.pending { detailTask?.cancel(); detailTask = nil }
        if hadDetail && viewport.detail == nil { publish() }
        guard !interactionActive, let request, let sensor else { return }
        let generation = generation
        let metrics = metrics
        detailTask = Task { @MainActor [weak self] in
            do {
                // Coalesce all plots and wait for drag deceleration to settle.
                try await Task.sleep(nanoseconds: 200_000_000)
                guard let self, generation == self.generation,
                      self.viewport?.pending == request else { return }
                let query = try CloudGraphQuery(sensors: [sensor], since: request.window.since,
                                               until: request.window.until, metrics: metrics)
                try await self.waitForRetryWindow()
                let response = try await self.load(query)
                try Task.checkCancellation()
                guard generation == self.generation, let series = response.series.first,
                      self.viewport?.accept(series, for: request) == true else { return }
                self.detailTask = nil
                self.publish()
                self.scheduleRefresh()
            } catch {
                guard let self, generation == self.generation, !Task.isCancelled,
                      self.viewport?.pending == request else { return }
                self.viewport?.fail(request)
                self.detailTask = nil
                self.handle(error)
            }
        }
    }

    private func publish() {
        guard let viewport else { return }
        if interactionActive { pendingDisplay = true } else { changed(viewport, true) }
    }

    private func handle(_ error: Error) {
        var lostAccess = false
        var retryAfter: TimeInterval = 60
        if let failure = error as? CloudGraphError {
            switch failure {
            case .unauthorized: lostAccess = true
            case .http(let status, let delay):
                lostAccess = status == 401 || status == 403
                retryAfter = max(60, delay ?? 0)
                if status == 429 || status == 503 {
                    let seconds = delay.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? 60
                    retryNotBefore = Date().addingTimeInterval(min(3600, seconds))
                }
                // A permanent size failure needs a shorter user-selected range, not a retry loop.
                if status == 413 { retryAfter = .infinity }
            case .unavailable, .invalid: retryAfter = .infinity
            }
        }
        if lostAccess { stop(clear: true) } else if retryAfter.isFinite { scheduleRefresh(after: retryAfter) }
        failed(error, lostAccess)
    }

    @MainActor private func waitForRetryWindow() async throws {
        if let retryNotBefore {
            let delay = max(0, retryNotBefore.timeIntervalSinceNow)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        try Task.checkCancellation()
    }

    private func scheduleRefresh(after delay: TimeInterval = 60) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, self.isVisible() else { return }
            self.refresh()
        }
    }
}
