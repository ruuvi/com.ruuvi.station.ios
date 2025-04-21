import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService
import SwiftUI
import Combine
import RuuviLocalization

class ChartViewModel: ObservableObject {

    let id: UUID

    @Published var chartTitle: String = ""
    @Published var unit: String = ""

    private(set) var chartEntity: NewTagChartEntity

    @Published var needsUpdate: Bool = false
    unowned let parenViewModel: ChartContainerViewModel
    private var cancellables = Set<AnyCancellable>()

    init(
        entity: NewTagChartEntity,
        parentViewModel: ChartContainerViewModel
    ) {
        self.id = entity.id
        self.chartEntity = entity
        self.parenViewModel = parentViewModel

        configureChartTitle(self, for: entity.chartType)

        setupSettingsObservers()
    }

    func updateChartEntity(_ entity: NewTagChartEntity) {
        if chartEntity.chartData !== entity.chartData ||
            chartEntity.lowerAlertValue != entity.lowerAlertValue ||
            chartEntity.upperAlertValue != entity.upperAlertValue {
            chartEntity = entity
            needsUpdate = true
        }
    }

    func setChartTitle(title: String, unit: String) {
        guard title != chartTitle || unit != self.unit else { return }
        self.chartTitle = title
        self.unit = unit
    }

    func getType() -> MeasurementType {
        return chartEntity.chartType
    }

    private func setupSettingsObservers() {
        // Only observe settings relevant to the current chart type
//        switch chartData.chartType {
//        case .temperature:
//            parenViewModel.$settings.temperatureUnit
//                .map { $0.temperatureUnit.symbol }
//                .removeDuplicates()
//                .sink { [weak self] symbol in
//                    self?.unit = symbol
//                    self?.needsUpdate = true
//                }
//                .store(in: &cancellables)
//        case .humidity:
//            parenViewModel.$settings
//                .map { $0.humidityUnit.symbol }
//                .removeDuplicates()
//                .sink { [weak self] symbol in
//                    self?.unit = symbol
//                    self?.needsUpdate = true
//                }
//                .store(in: &cancellables)
//        case .pressure:
//            parenViewModel.$settings
//                .map { $0.pressureUnit.symbol }
//                .removeDuplicates()
//                .sink { [weak self] symbol in
//                    self?.unit = symbol
//                    self?.needsUpdate = true
//                }
//                .store(in: &cancellables)
//        default:
//            break
//        }

        // Observe chart stat visibility changes
        parenViewModel.$showChartStat
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.needsUpdate = true
            }
            .store(in: &cancellables)

        // Observe show all points changes
        parenViewModel.$showAllPoints
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.needsUpdate = true
            }
            .store(in: &cancellables)

        // Observe duration changes
        parenViewModel.$chartDurationHours
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.needsUpdate = true
            }
            .store(in: &cancellables)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func configureChartTitle(
        _ viewModel: ChartViewModel,
        for chartType: MeasurementType
    ) {
        switch chartType {
        case .temperature:
            viewModel.setChartTitle(
                title: RuuviLocalization.TagSettings.OffsetCorrection.temperature,
                unit: parenViewModel.settings.temperatureUnit.symbol
            )
        case .humidity:
            viewModel.setChartTitle(
                title: RuuviLocalization.TagSettings.OffsetCorrection.humidity,
                unit: parenViewModel.settings.humidityUnit.symbol
            )
        case .pressure:
            viewModel.setChartTitle(
                title: RuuviLocalization.TagSettings.OffsetCorrection.pressure,
                unit: parenViewModel.settings.pressureUnit.symbol
            )
        case .aqi:
            viewModel.setChartTitle(
                title: RuuviLocalization.aqi,
                unit: "%"
            )
        case .co2:
            viewModel.setChartTitle(
                title: RuuviLocalization.co2,
                unit: RuuviLocalization.unitCo2
            )
        case .pm10:
            viewModel.setChartTitle(
                title: RuuviLocalization.pm10,
                unit: RuuviLocalization.unitPm10
            )
        case .pm25:
            viewModel.setChartTitle(
                title: RuuviLocalization.pm25,
                unit: RuuviLocalization.unitPm25
            )
        case .voc:
            viewModel.setChartTitle(
                title: RuuviLocalization.voc,
                unit: RuuviLocalization.unitVoc
            )
        case .nox:
            viewModel.setChartTitle(
                title: RuuviLocalization.nox,
                unit: RuuviLocalization.unitNox
            )
        case .luminosity:
            viewModel.setChartTitle(
                title: RuuviLocalization.luminosity,
                unit: RuuviLocalization.unitLuminosity
            )
        case .sound:
            viewModel.setChartTitle(
                title: RuuviLocalization.sound,
                unit: RuuviLocalization.unitSound
            )
        default:
            break
        }
    }
}
