import Combine
import Foundation
import RuuviLocal

/// Calculates freshness once per snapshot and reads the configured timeout once per batch.
@MainActor
final class MeasurementFreshnessService {
    static let shared = MeasurementFreshnessService(timeout: {
        AppAssembly.shared.assembler.resolver.resolve(RuuviLocalFlags.self)?.measurementStaleTimeoutSeconds
            ?? RuuviMeasurementFreshness.defaultTimeoutSeconds
    })

    private struct Entry {
        weak var snapshot: RuuviTagCardSnapshot?
        let observation: AnyCancellable
    }
    private let gate: MeasurementFreshnessGate
    private let timeout: () -> Int
    private let now: () -> Date
    private let identity: (RuuviTagCardSnapshot) -> ObjectIdentifier
    private var entries: [ObjectIdentifier: Entry] = [:]
    private var refreshScheduled = false

    init(
        gate: MeasurementFreshnessGate? = nil,
        timeout: @escaping () -> Int = { RuuviMeasurementFreshness.defaultTimeoutSeconds },
        now: @escaping () -> Date = Date.init,
        identity: @escaping (RuuviTagCardSnapshot) -> ObjectIdentifier = ObjectIdentifier.init
    ) {
        self.gate = gate ?? .shared
        self.timeout = timeout
        self.now = now
        self.identity = identity
    }

    func track(_ snapshot: RuuviTagCardSnapshot) {
        let key = identity(snapshot)
        if entries[key]?.snapshot === snapshot {
            update(snapshot, timeout: timeout(), now: now())
            return
        }
        // @Published emits before assignment. Read the resulting snapshot on the next main turn.
        let observation = Publishers.Merge3(
            snapshot.$lastUpdated.removeDuplicates().dropFirst().map { _ in () },
            snapshot.$displayData.map(\.source).removeDuplicates().dropFirst().map { _ in () },
            snapshot.$metadata.map(\.isCloud).removeDuplicates().dropFirst().map { _ in () }
        ).receive(on: DispatchQueue.main).sink { [weak self] _ in self?.scheduleRefresh() }
        entries[key] = Entry(snapshot: snapshot, observation: observation)
        TimestampUpdateService.shared.addFreshnessService(self)
        update(snapshot, timeout: timeout(), now: now())
    }

    func refresh() {
        entries = entries.filter { $0.value.snapshot != nil }
        guard !entries.isEmpty else { return }
        let timeout = timeout()
        let now = now()
        for entry in entries.values {
            if let snapshot = entry.snapshot { update(snapshot, timeout: timeout, now: now) }
        }
    }

    private func update(_ snapshot: RuuviTagCardSnapshot, timeout: Int, now: Date) {
        snapshot.updateMeasurementFreshness(gate.shouldShowWarning(for: snapshot, timeoutSeconds: timeout, now: now))
    }

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.refreshScheduled = false
            self?.refresh()
        }
    }
}
