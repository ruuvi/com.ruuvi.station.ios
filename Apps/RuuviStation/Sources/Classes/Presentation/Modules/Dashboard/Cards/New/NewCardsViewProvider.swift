import RuuviOntology
import SwiftUI
import Combine
import RuuviService
import RuuviStorage
import DGCharts
import RuuviLocal

class NewCardsViewProvider: NSObject {
    var output: NewCardsViewOutput?

    private var measurementService: RuuviServiceMeasurement!
    private var settings: RuuviLocalSettings!
    private var flags: RuuviLocalFlags!

    private var cancellables = Set<AnyCancellable>()
    private var transitionHandler: UIViewController?

    // MARK: CardsViewInput
    var state: NewCardsViewState = NewCardsViewState()

    func makeViewController(transitionHandler: UIViewController?) -> UIViewController {
        // Store the transition handler
        self.transitionHandler = transitionHandler
        self.transitionHandler?.navigationController?.navigationBar.isHidden = true

        // Create the hosting controller with the state injected
        let hostingController = UIHostingController(
            rootView: NewCardsView(
                measurementService: measurementService,
                settings: settings,
                flags: flags
            )
            .environmentObject(state)
        )

        return hostingController
    }

    override init() {
        super.init()

        let r = AppAssembly.shared.assembler.resolver
        measurementService = r.resolve(RuuviServiceMeasurement.self)!
        settings = r.resolve(RuuviLocalSettings.self)!
        flags = r.resolve(RuuviLocalFlags.self)!

        // Subscribe to back button tap events
        state.backButtonTapped
            .sink { [weak self] _ in
                // TODO: CLEANUP
                self?.transitionHandler?.navigationController?.navigationBar.isHidden = false
                // Get the navigation controller and pop
                if let navigationController = self?.transitionHandler?.navigationController {
                    navigationController.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)

        // Subscribe to graph button tap events
        state.graphButtonTapped
            .sink { [weak self] viewModel in
                self?.output?.showGraphForViewModel(viewModel)
            }
            .store(in: &cancellables)

        // Subscribe to graph button tap events
        state.$currentPage
            .sink { [weak self] currentPage in
                if self?.state.selectedTab == .graph {
                    if let viewModel = self?.state.viewModels[currentPage] {
                        self?.output?.showGraphForViewModel(viewModel)
                    }
                }
            }
            .store(in: &cancellables)
    }
}

extension NewCardsViewProvider: NewCardsViewInput {

    func createChartViews(from: [MeasurementType], for sensor: RuuviTagSensor) {
        state.chartViewModel?.setChartViewData(from.compactMap({ type in
            NewTagChartViewData(ruuviTagId: sensor.id, chartType: type)
        }))
    }

    func setChartViewData(
        from chartViewData: [NewTagChartViewData],
        for sensor: RuuviTagSensor,
        settings: RuuviLocalSettings
    ) {
        for newItem in chartViewData {
            // 1) Find the matching item in existingData
            if let index = state.chartViewModel?.chartViewData.firstIndex(where: {
                $0.ruuviTagId == newItem.ruuviTagId &&
                $0.chartType == newItem.chartType
            }) {
                // 2) Update the matching item’s published properties
                state.chartViewModel?.chartViewData[index].upperAlertValue = newItem.upperAlertValue
                state.chartViewModel?.chartViewData[index].chartData       = newItem.chartData
                state.chartViewModel?.chartViewData[index].lowerAlertValue = newItem.lowerAlertValue
            }
        }

        state.graphLoadingState = .finished
    }

    // swiftlint:disable:next function_parameter_count
    func updateChartViewData(
        for sensor: RuuviTagSensor,
        temperatureEntries: [ChartDataEntry],
        humidityEntries: [ChartDataEntry],
        pressureEntries: [ChartDataEntry],
        aqiEntries: [ChartDataEntry],
        co2Entries: [ChartDataEntry],
        pm10Entries: [ChartDataEntry],
        pm25Entries: [ChartDataEntry],
        vocEntries: [ChartDataEntry],
        noxEntries: [ChartDataEntry],
        luminosityEntries: [ChartDataEntry],
        soundEntries: [ChartDataEntry],
        isFirstEntry: Bool,
        settings: RuuviLocalSettings,
        flags: RuuviLocalFlags
    ) {
        print("updateChartViewData")

        if let index = state.chartViewModel?.chartViewData.firstIndex(where: {
            $0.ruuviTagId == sensor.id
        }) {
            if state.chartViewModel?.chartViewData[index].chartType == .temperature {
                state.chartViewModel?.chartViewData[index].dataSet = temperatureEntries
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    func updateLatestMeasurement(
        for sensor: RuuviTagSensor,
        temperature: ChartDataEntry?,
        humidity: ChartDataEntry?,
        pressure: ChartDataEntry?,
        aqi: ChartDataEntry?,
        co2: ChartDataEntry?,
        pm10: ChartDataEntry?,
        pm25: ChartDataEntry?,
        voc: ChartDataEntry?,
        nox: ChartDataEntry?,
        luminosity: ChartDataEntry?,
        sound: ChartDataEntry?,
        settings: RuuviLocalSettings
    ) {

    }

//    func applyUpdate(to viewModel: CardsViewModel) {
//
//    }
//
//    func scroll(to index: Int) {
//
//    }
//
//    func showBluetoothDisabled(userDeclined: Bool) {
//
//    }
//
//    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
//
//    }
//
//    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
//
//    }
//
//    func showFirmwareUpdateDialog(for viewModel: CardsViewModel) {
//
//    }
//
//    func showFirmwareDismissConfirmationUpdateDialog(
//        for viewModel: CardsViewModel
//    ) {
//
//    }
//
//    func showReverseGeocodingFailed() {
//
//    }
//
//    func showAlreadyLoggedInAlert(with email: String) {
//
//    }
//
//    func viewShouldDismiss() {
//
//    }

}

class NewCardsViewState: ObservableObject {
    // MARK: Properties
    @Published var currentPage: Int = 0
    @Published var scrollProgress: CGFloat = 0
    @Published var isScrolling: Bool = false

    @Published var selectedTab: SensorCardSelectedTab = .home

    @Published var viewModels: [CardsViewModel] = []
    @Published var ruuviTags: [AnyRuuviTagSensor] = []
    @Published var sensorSettings: [SensorSettings] = []

    @Published var graphLoadingState: GraphLoadingState = .initial
    @Published var chartViewModel: ChartContainerViewModel?

    // MARK: Actions
    let backButtonTapped = PassthroughSubject<Void, Never>()
    let graphButtonTapped = PassthroughSubject<CardsViewModel, Never>()
}

enum GraphLoadingState {
    case initial
    case loading
    case finished
}
