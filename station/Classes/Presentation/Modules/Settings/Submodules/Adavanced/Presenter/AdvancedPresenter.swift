import Foundation

class AdvancedPresenter: NSObject, AdvancedModuleInput {
    weak var view: AdvancedViewInput!
    var router: AdvancedRouterInput!
    var settings: Settings!
    private var chartIntervalDidChanged: Bool = false

    func configure() {
        view.viewModels = [buildChartIntervalSeconds(),
                           buildChartDownsampling()]
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
    private func buildChartIntervalSeconds() -> AdvancedViewModel {
        let chartIntervalSeconds = AdvancedViewModel()
        chartIntervalSeconds.title = "Advanced.ChartIntervalMinutes.title".localized()
        chartIntervalSeconds.integer.value = settings.chartIntervalSeconds / 60
        chartIntervalSeconds.unit = .minutes

        bind(chartIntervalSeconds.integer, fire: false) {[weak self] observer, chartIntervalSeconds in
            self?.chartIntervalDidChanged = true
            observer.settings.chartIntervalSeconds = chartIntervalSeconds.bound * 60
        }
        return chartIntervalSeconds
    }

    private func buildChartDownsampling() -> AdvancedViewModel {
        let downsamplingOn = AdvancedViewModel()
        downsamplingOn.title = "Advanced.Downsampling.title".localized()
        downsamplingOn.boolean.value = settings.chartDownsamplingOn

        bind(downsamplingOn.boolean, fire: false) { observer, downsamplingOn in
            observer.settings.chartDownsamplingOn = downsamplingOn.bound
        }
        return downsamplingOn
    }
}
