import Combine
import UIKit
import RuuviLocalization

/// A single binding keeps the source badge, timestamp text and freshness callback consistent.
@MainActor
final class MeasurementFreshnessBinding: TimestampUpdateable {
    var onFresh: ((RuuviTagCardSnapshot) -> Void)?
    private let button: SensorDataSourceButton
    private let timestamp: UILabel
    private weak var snapshot: RuuviTagCardSnapshot?
    private var observation: AnyCancellable?
    private var lastStaleState: Bool?
    private var live = false

    init(button: SensorDataSourceButton, timestamp: UILabel) {
        self.button = button
        self.timestamp = timestamp
    }

    func bind(_ snapshot: RuuviTagCardSnapshot?, service: MeasurementFreshnessService?) {
        guard self.snapshot !== snapshot || live != (service != nil) else { return }
        observation = nil
        self.snapshot = snapshot
        live = service != nil
        lastStaleState = nil
        if let snapshot, let service {
            service.track(snapshot)
            observation = snapshot.$isOutdated.sink { [weak self] isOutdated in
                self?.setStale(isOutdated)
            }
            TimestampUpdateService.shared.addSubscriber(self)
        } else {
            TimestampUpdateService.shared.removeSubscriber(self)
            setStale(false)
        }
        updateTimestampLabel()
    }

    func updateTimestampLabel() {
        button.update(source: snapshot?.displayData.source, isStale: live && (lastStaleState ?? false))
        timestamp.text = snapshot?.lastUpdated?.ruuviAgo() ?? RuuviLocalization.Cards.UpdatedLabel.NoData.message
    }

    private func setStale(_ stale: Bool) {
        button.update(source: snapshot?.displayData.source, isStale: stale)
        guard lastStaleState != stale else { return }
        lastStaleState = stale
        if live, !stale, let snapshot { onFresh?(snapshot) }
    }
}
