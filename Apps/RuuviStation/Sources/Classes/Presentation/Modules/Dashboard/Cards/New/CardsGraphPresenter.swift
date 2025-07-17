import UIKit
import RuuviLocal
import RuuviOntology

// MARK: - Graph Presenter
final class CardsGraphPresenter: CardsGraphViewOutput {

    // MARK: - Properties
    weak var view: CardsGraphViewInput?

    // MARK: - Services
    private let dataService: RuuviTagDataService
    private let settings: RuuviLocalSettings

    // MARK: - State
    private var currentSnapshot: RuuviTagCardSnapshot?
    private var selectedTimeRange: GraphTimeRange = .day1

    // MARK: - Initialization
    init(
        dataService: RuuviTagDataService,
        settings: RuuviLocalSettings
    ) {
        self.dataService = dataService
        self.settings = settings
    }

    // MARK: - Public Methods
    func updateCurrentSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        currentSnapshot = snapshot
        view?.showSelectedSnapshot(snapshot)
    }

    // MARK: - CardsGraphViewOutput
    func graphViewDidLoad() {
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func graphViewDidBecomeActive() {
        view?.updateGraphData()
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func graphViewDidSelectTimeRange(_ range: GraphTimeRange) {
        selectedTimeRange = range
        print("Selected time range: \(range.title)")

        // TODO: Load graph data for the selected time range
        // This would typically:
        // - Query historical data from storage
        // - Process data for the chart
        // - Update the graph view

        view?.updateGraphData()
    }
}
