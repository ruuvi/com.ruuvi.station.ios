#if SWIFT_PACKAGE
    import RuuviDaemon
#endif
import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor

public final class RuuviTagPropertiesDaemonBTKit: RuuviTagPropertiesDaemon {
    private let client: SensorPropertiesDaemonClient
    private let lock = NSRecursiveLock()
    private var epoch: UUID?
    private var sensors = [AnyRuuviTagSensor]()
    private var observation: (() -> Void)?
    private var scan: (() -> Void)?
    private var jobs = [String: Job]()

    private struct Job {
        let id: UUID
        let task: Task<Void, Never>
    }

    public convenience init(
        ruuviPool: RuuviPool,
        ruuviReactor: RuuviReactor,
        foreground: BTForeground,
        idPersistence: RuuviLocalIDs,
        sqiltePersistence: RuuviPersistence
    ) {
        self.init(
            client: .live(
                pool: ruuviPool, reactor: ruuviReactor, foreground: foreground,
                identifiers: idPersistence, persistence: sqiltePersistence))
    }

    init(client: SensorPropertiesDaemonClient) { self.client = client }
    deinit { stop() }

    public func start() {
        lock.withLock {
            guard epoch == nil else { return }
            let session = UUID()
            epoch = session
            observation = client.observeSensors { [weak self] change in self?.receive(change, session: session) }
        }
    }

    public func stop() {
        lock.withLock {
            epoch = nil
            observation?()
            observation = nil
            scan?()
            scan = nil
            jobs.values.forEach { $0.task.cancel() }
            jobs.removeAll()
            sensors.removeAll()
        }
    }

    private func receive(_ change: RuuviReactorChange<AnyRuuviTagSensor>, session: UUID) {
        lock.withLock {
            guard epoch == session else { return }
            switch change {
            case .initial(let initial):
                let retained = Set(initial.map(\.id))
                for key in Array(jobs.keys) where !retained.contains(key) {
                    jobs.removeValue(forKey: key)?.task.cancel()
                }
                sensors = initial
            case .insert(let sensor), .update(let sensor):
                if let index = sensors.firstIndex(where: { Self.matches($0, sensor) }) {
                    sensors[index] = sensor
                } else {
                    sensors.append(sensor)
                }
            case .delete(let sensor):
                remove(sensor)
            case .error(let error):
                report(.ruuviReactor(error), session: session)
            }
            if sensors.isEmpty {
                scan?()
                scan = nil
            } else if scan == nil {
                scan = client.scan { [weak self] device in self?.receive(device, session: session) }
            }
        }
    }

    private func receive(_ device: SensorPropertiesAdvertisement, session: UUID) {
        lock.withLock {
            guard epoch == session, !device.luid.isEmpty else { return }
            if let sensor = sensors.first(where: { $0.luid?.value == device.luid }) {
                var updated = sensor.struct
                if device.mac != sensor.macId?.value {
                    guard let mapped = client.macForLuid(device.luid), !mapped.isEmpty else { return }
                    updated.macId = mapped.mac
                }
                updated.version = device.version
                guard updated.version != sensor.version || updated.macId?.value != sensor.macId?.value else { return }
                enqueue(sensor, session: session) { updated }
            } else if let mac = device.mac, !mac.isEmpty,
                let sensor = matchingSensor(mac: mac)
            {
                if sensor.luid == nil, sensor.isCloud {
                    var updated = sensor.struct
                    updated.luid = device.luid.luid
                    updated.version = device.version
                    updated.serviceUUID = device.serviceUUID
                    updated.isConnectable = device.isConnectable
                    enqueue(sensor, session: session) { updated }
                } else {
                    // Read the current row before rebinding a changed Bluetooth identifier.
                    let read = client.readSensor
                    enqueue(sensor, session: session) {
                        try await read(sensor.id).with(luid: device.luid.luid)
                    }
                }
            }
        }
    }

    private func enqueue(
        _ sensor: RuuviTagSensor, session: UUID,
        prepare: @escaping @MainActor () async throws -> RuuviTagSensor
    ) {
        let key = sensor.id
        guard jobs[key] == nil else { return }
        let id = UUID()
        let update = client.updateSensor
        let task = Task { @MainActor [weak self] in
            defer { self?.finish(key: key, id: id) }
            do {
                guard self?.isCurrent(key: key, id: id, session: session) == true else { return }
                let updated = try await prepare()
                try Task.checkCancellation()
                guard self?.isCurrent(key: key, id: id, session: session) == true else { return }
                let saved = try await update(updated)
                if saved, !Task.isCancelled {
                    self?.didSave(updated, replacing: sensor, session: session)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.failed(error, sensor: sensor, session: session)
            }
        }
        jobs[key] = Job(id: id, task: task)
    }

    private func isCurrent(key: String, id: UUID, session: UUID) -> Bool {
        lock.withLock { epoch == session && jobs[key]?.id == id }
    }

    private func finish(key: String, id: UUID) {
        lock.withLock { if jobs[key]?.id == id { jobs[key] = nil } }
    }

    private func didSave(_ updated: RuuviTagSensor, replacing sensor: RuuviTagSensor, session: UUID) {
        lock.withLock {
            guard epoch == session, let index = sensors.firstIndex(where: { Self.matches($0, sensor) }) else { return }
            sensors[index] = updated.any
        }
    }

    private func failed(_ error: Error, sensor: RuuviTagSensor, session: UUID) {
        lock.withLock {
            guard epoch == session else { return }
            if let poolError = error as? RuuviPoolError {
                if case .ruuviPersistence(.failedToFindRuuviTag) = poolError {
                    remove(sensor)
                } else {
                    report(.ruuviPool(poolError), session: session)
                }
            } else if let persistenceError = error as? RuuviPersistenceError {
                if case .failedToFindRuuviTag = persistenceError {
                    remove(sensor)
                } else {
                    report(.ruuviPersistence(persistenceError), session: session)
                }
            }
            if sensors.isEmpty { scan?(); scan = nil }
        }
    }

    private func remove(_ sensor: RuuviTagSensor) {
        for stored in sensors where Self.matches(stored, sensor) {
            jobs.removeValue(forKey: stored.id)?.task.cancel()
        }
        sensors.removeAll { Self.matches($0, sensor) }
    }

    private func report(_ error: RuuviDaemonError, session: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.withLock {
                guard self.epoch == session else { return }
                self.client.report(error)
            }
        }
    }

    private func matchingSensor(mac: String) -> AnyRuuviTagSensor? {
        // Prefer an exact full address. A shortened advertisement must identify one saved sensor.
        let exact = sensors.filter { $0.macId?.value.caseInsensitiveCompare(mac) == .orderedSame }
        if exact.count == 1 { return exact[0] }
        let candidates = sensors.filter { Self.matchesMAC($0.macId?.value, mac) }
        return candidates.count == 1 ? candidates[0] : nil
    }

    private static func matchesMAC(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs else { return false }
        let clean: (String) -> String = { value in
            value.lowercased().filter { "0123456789abcdef".contains($0) }
        }
        let left = clean(lhs)
        let right = clean(rhs)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }
        return ([6, 8].contains(left.count) || [6, 8].contains(right.count)) && left.suffix(6) == right.suffix(6)
    }

    private static func matches(_ lhs: RuuviTagSensor, _ rhs: RuuviTagSensor) -> Bool {
        Self.matchesMAC(lhs.macId?.value, rhs.macId?.value)
            || (lhs.luid != nil && lhs.luid?.value == rhs.luid?.value)
    }
}
