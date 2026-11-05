import Foundation
import RuuviOntology
import RuuviReactor

final class AppTestReactor: RuuviReactor {
    var sensors = [UUID: (RuuviReactorChange<AnyRuuviTagSensor>) -> Void]()
    var latest = [UUID: (String, (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void)]()
    var settings = [UUID: (String, (RuuviReactorChange<SensorSettings>) -> Void)]()
    var records = [UUID: ([AnyRuuviTagSensorRecord]) -> Void]()

    func observe(_ block: @escaping (RuuviReactorChange<AnyRuuviTagSensor>) -> Void) -> RuuviReactorToken {
        let id = UUID()
        sensors[id] = block
        return .init { [weak self] in self?.sensors.removeValue(forKey: id) }
    }
    func observe(_ luid: LocalIdentifier, _ block: @escaping ([AnyRuuviTagSensorRecord]) -> Void) -> RuuviReactorToken {
        let id = UUID()
        records[id] = block
        return .init { [weak self] in self?.records.removeValue(forKey: id) }
    }
    func observeLatest(
        _ sensor: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        let id = UUID()
        latest[id] = (sensor.id, block)
        return .init { [weak self] in self?.latest.removeValue(forKey: id) }
    }
    func observeLast(
        _ sensor: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<AnyRuuviTagSensorRecord?>) -> Void
    ) -> RuuviReactorToken {
        observeLatest(sensor, block)
    }
    func observe(
        _ sensor: RuuviTagSensor,
        _ block: @escaping (RuuviReactorChange<SensorSettings>) -> Void
    ) -> RuuviReactorToken {
        let id = UUID()
        settings[id] = (sensor.id, block)
        return .init { [weak self] in self?.settings.removeValue(forKey: id) }
    }
    func sendLatest(_ sensor: RuuviTagSensor, _ change: RuuviReactorChange<AnyRuuviTagSensorRecord?>) {
        for (id, callback) in latest.values where id == sensor.id { callback(change) }
    }
    func sendSettings(_ sensor: RuuviTagSensor, _ change: RuuviReactorChange<SensorSettings>) {
        for (id, callback) in settings.values where id == sensor.id { callback(change) }
    }
}

@MainActor func flushAppBindings() async {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
    }
}
