import Combine

final class RuuviSensorCardItem: ObservableObject, Identifiable {
    @Published private(set) var snapshot: SensorSnapshot
    var id: String { snapshot.id }

    init(initialSnapshot: SensorSnapshot) {
        self.snapshot = initialSnapshot
    }

    /// Presenter calls this whenever *anything* about the sensor changes.
    func apply(_ newSnapshot: SensorSnapshot) {
        guard snapshot != newSnapshot else { return }
        snapshot = newSnapshot
    }
}
