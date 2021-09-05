import Foundation
import RuuviLocal

class AdvancedPresenter: NSObject, AdvancedModuleInput {
    weak var view: AdvancedViewInput!
    var router: AdvancedRouterInput!
    var settings: RuuviLocalSettings!
    var featureToggleService: FeatureToggleService!

    private var chartIntervalDidChanged: Bool = false
    private var viewModel: AdvancedViewModel = AdvancedViewModel(sections: []) {
        didSet {
            view.viewModel = viewModel
        }
    }

    func configure() {
        var sections: [AdvancedSection] = []
        sections.append(buildChartsSection())
        viewModel = AdvancedViewModel(sections: sections)
    }

    private func buildChartsSection() -> AdvancedSection {
        return AdvancedSection(
            title: "Advanced.Charts.title".localized(),
            cells: [
                buildChartDownsampling(),
                buildChartIntervalSeconds()
            ]
        )
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
}

// MARK: Private
extension AdvancedPresenter {
    private func buildChartIntervalSeconds() -> AdvancedCell {
        let title = "Advanced.ChartIntervalMinutes.title".localized()
        let value = settings.chartIntervalSeconds / 60
        let unit = AdvancedIntegerUnit.minutes
        let type: AdvancedCellType = .stepper(
            title: title,
            value: value,
            unit: unit
        )
        let cell = AdvancedCell(type: type)
        cell.integer.value = value
        bind(cell.integer, fire: false) { observer, value in
            guard let value = value else { return }
            observer.chartIntervalDidChanged = true
            observer.settings.chartIntervalSeconds = value * 60
        }
        return cell
    }

    private func buildChartDownsampling() -> AdvancedCell {
        let title = "Advanced.Downsampling.title".localized()
        let value = settings.chartDownsamplingOn
        let type: AdvancedCellType = .switcher(title: title,
                         value: value)
        let cell = AdvancedCell(type: type)
        cell.boolean.value = value
        bind(cell.boolean, fire: false) { observer, value in
            guard let value = value else { return }
            observer.settings.chartDownsamplingOn = value
        }
        return cell
    }
}
