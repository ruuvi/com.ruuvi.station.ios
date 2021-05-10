import Foundation

class AdvancedPresenter: NSObject, AdvancedModuleInput {
    weak var view: AdvancedViewInput!
    var router: AdvancedRouterInput!
    var settings: Settings!
    var featureToggleService: FeatureToggleService!

    private var chartIntervalDidChanged: Bool = false
    private var viewModel: AdvancedViewModel = AdvancedViewModel(sections: []) {
        didSet {
            view.viewModel = viewModel
        }
    }

    func configure() {
        let chartsSection = AdvancedSection(title: "Advanced.Charts.title".localized(),
                                            cells: [
            buildChartDownsampling(),
            buildChartIntervalSeconds()
        ])
        var sections: [AdvancedSection] = []
        sections.append(chartsSection)
        if featureToggleService.isEnabled(.network) {
            let ruuviNetworkSection = AdvancedSection(title: "Advanced.RuuviNetwork.Section.title".localized(),
                                                      cells: [
                buildRuuviNetwork()
            ])
            sections.append(ruuviNetworkSection)
        }
        viewModel = AdvancedViewModel(sections: sections)
    }
}

// MARK: - AdvancedViewOutput
extension AdvancedPresenter: AdvancedViewOutput {
    func viewWillDisappear() {
        if chartIntervalDidChanged {
            NotificationCenter
                .default
                .post(name: .ChartIntervalDidChange, object: self)
        }
    }

    func viewDidChangeStepperValue(for index: Int, newValue: Int) {
        chartIntervalDidChanged = true
        settings.chartIntervalSeconds = newValue * 60
    }

    func viewDidChangeSwitchValue(for index: Int, newValue: Bool) {
        settings.chartDownsamplingOn = newValue
    }

    func viewDidPress(at indexPath: IndexPath) {
        if case AdvancedCellType.disclosure(let title) = viewModel.sections[indexPath.section].cells[indexPath.row],
            title == "NetworkSettings.title".localized() {
            router.openNetworkSettings()
        }
    }
}

// MARK: Private
extension AdvancedPresenter {
    private func buildChartIntervalSeconds() -> AdvancedCellType {
        let title = "Advanced.ChartIntervalMinutes.title".localized()
        let value = settings.chartIntervalSeconds / 60
        let unit = AdvancedIntegerUnit.minutes
        return .stepper(title: title,
                        value: value,
                        unit: unit)
    }

    private func buildChartDownsampling() -> AdvancedCellType {
        let title = "Advanced.Downsampling.title".localized()
        let value = settings.chartDownsamplingOn
        return .switcher(title: title,
                         value: value)
    }

    private func buildRuuviNetwork() -> AdvancedCellType {
        let title = "NetworkSettings.title".localized()
        return .disclosure(title: title)
    }
}
