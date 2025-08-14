import RuuviOntology
import Foundation

class CardsMeasurementPresenter: NSObject {
    weak var view: CardsMeasurementViewInput?
    weak var output: CardsMeasurementPresenterOutput?

    private var snapshots: [RuuviTagCardSnapshot] = []
    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: AnyRuuviTagSensor?
}

// MARK: CardsMeasurementPresenterInput
extension CardsMeasurementPresenter: CardsMeasurementPresenterInput {
    func configure(
        with snapshots: [RuuviTagCardSnapshot],
        snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?
    ) {
        self.snapshots = snapshots
        configure(with: snapshot, sensor: sensor)
    }

    func scroll(to index: Int, animated: Bool) {
        view?.navigateToIndex(index, animated: animated)
    }

    func configure(
        with snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?
    ) {
        self.snapshot = snapshot
        self.sensor = sensor
    }

    func configure(
        output: CardsMeasurementPresenterOutput?
    ) {
        self.output = output
    }

    func start() {
        var currentIndex: Int = 0
        if let snapshot = snapshot {
            currentIndex = snapshots.firstIndex(where: {
                $0.id == snapshot.id &&
                $0.identifierData.luid?.value == snapshot.identifierData.luid?.value &&
                $0.identifierData.mac?.value == snapshot.identifierData.mac?.value
            }) ?? 0
        }
        view?.updateSnapshots(snapshots, currentIndex: currentIndex)
    }

    func stop() {}
}

// MARK: CardsMeasurementViewOutput
extension CardsMeasurementPresenter: CardsMeasurementViewOutput {
    func viewWillAppear(sender: CardsMeasurementViewController) {
        start()
    }

    func viewDidScroll(
        to index: Int,
        sender: CardsMeasurementViewController
    ) {
        output?.measurementPresenter(self, didNavigateToIndex: index)
    }
}
