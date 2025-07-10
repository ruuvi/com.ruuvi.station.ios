import Foundation
import RuuviOntology
import RuuviService
import RuuviLocal

// MARK: - Measurement Presenter
final class CardsMeasurementPresenter: CardsMeasurementViewOutput {

    // MARK: - Properties
    weak var view: CardsMeasurementViewInput?

    // MARK: - Services
    private let dataService: RuuviTagDataService
    private let alertService: RuuviTagAlertService
    private let settings: RuuviLocalSettings

    // MARK: - State
    private var allSnapshots: [RuuviTagCardSnapshot] = []
    private var currentSnapshotIndex: Int = 0

    // MARK: - Callbacks
    var onSnapshotIndexChanged: ((Int) -> Void)?

    // MARK: - Initialization
    init(
        dataService: RuuviTagDataService,
        alertService: RuuviTagAlertService,
        settings: RuuviLocalSettings
    ) {
        self.dataService = dataService
        self.alertService = alertService
        self.settings = settings
    }

    // MARK: - Public Methods
    func updateCurrentSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        // This is for single snapshot updates - use the new method
        guard let snapshot = snapshot else { return }

        // If we're in multi-snapshot mode, update the specific snapshot
        if !allSnapshots.isEmpty {
            view?.updateCurrentSnapshotData(snapshot)
        } else {
            // Fallback to single snapshot mode (backward compatibility)
            view?.showSelectedSnapshot(snapshot)
        }
    }

    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int) {
        allSnapshots = snapshots
        currentSnapshotIndex = currentIndex
        view?.updateSnapshots(snapshots, currentIndex: currentIndex)
    }

    func navigateToIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < allSnapshots.count else { return }
        currentSnapshotIndex = index
        view?.navigateToIndex(index, animated: animated)
    }

    // MARK: - CardsMeasurementViewOutput
    func measurementViewDidLoad() {
        // Don't automatically show current snapshot here - let the main presenter handle setup
    }

    func measurementViewDidBecomeActive() {
        // Refresh measurement data when tab becomes active
        view?.updateMeasurementData()
    }

    func measurementViewDidSelectMeasurement(_ type: MeasurementType) {
        print("Selected measurement: \(type)")

        // Get current snapshot
        guard currentSnapshotIndex < allSnapshots.count else { return }
        let currentSnapshot = allSnapshots[currentSnapshotIndex]

        // Get specific measurement data
        if let indicators = currentSnapshot.displayData.indicatorGrid?.indicators,
           let indicator = indicators.first(where: { $0.type == type }) {
            view?.presentIndicatorDetailsSheet(for: type, with: currentSnapshot)
            print("Measurement value: \(indicator.value) \(indicator.unit)")
        }
    }

    func measurementViewDidChangeSnapshotIndex(_ index: Int) {
        guard index != currentSnapshotIndex else { return }
        currentSnapshotIndex = index
        onSnapshotIndexChanged?(index)
    }
}
