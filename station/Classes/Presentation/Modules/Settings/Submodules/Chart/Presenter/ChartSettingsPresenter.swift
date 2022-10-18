import Foundation
import RuuviLocal
import RuuviService

class ChartSettingsPresenter: NSObject, ChartSettingsModuleInput {
    weak var view: ChartSettingsViewInput!
    var router: ChartSettingsRouterInput!
    var settings: RuuviLocalSettings!
    var featureToggleService: FeatureToggleService!
    var ruuviAppSettingsService: RuuviServiceAppSettings!

    private var timer: Timer?
    private var chartIntervalDidChanged: Bool = false
    private var viewModel: ChartSettingsViewModel = ChartSettingsViewModel(sections: []) {
        didSet {
            view.viewModel = viewModel
        }
    }

    func configure() {
        let sections: [ChartSettingsSection] = [
            buildDisplayAllDataSection(), buildChartHistorySection()
        ]
        viewModel = ChartSettingsViewModel(sections: sections)
    }

    private func buildDisplayAllDataSection() -> ChartSettingsSection {
        return ChartSettingsSection(
            note: "ChartSettings.AllPoints.description".localized(),
            cells: [
                buildChartDownsampling()
            ]
        )
    }

    // Draw dots feature is disabled from v1.3.0 onwards to
    // maintain better performance until we find a better approach to do it.
    private func buildDrawDotsSection() -> ChartSettingsSection {
        return ChartSettingsSection(
            note: "ChartSettings.DrawDots.description".localized(),
            cells: [
                buildChartDotsDrawing()
            ]
        )
    }

    private func buildChartHistorySection() -> ChartSettingsSection {
        return ChartSettingsSection(
            note: "ChartSettings.Duration.description".localized(),
            cells: [
                buildChartHistory()
            ]
        )
    }
}

// MARK: - ChartSettingsViewOutput
extension ChartSettingsPresenter: ChartSettingsViewOutput {
    func viewWillDisappear() {
        if chartIntervalDidChanged {
            NotificationCenter
                .default
                .post(name: .ChartIntervalDidChange, object: self)
        }

        // If there's a timer running it refers that user changed the chart duration value
        // and before leaving the screen it is necessary to sync the value to the cloud
        if timer != nil {
            DispatchQueue.main.async { [weak self] in
                self?.syncChartDuratingSettings()
            }
        }
    }
}

// MARK: Private
extension ChartSettingsPresenter {

    private func buildChartDownsampling() -> ChartSettingsCell {
        let title = "ChartSettings.AllPoints.title".localized()
        let value = !settings.chartDownsamplingOn
        let type: ChartSettingsCellType = .switcher(title: title,
                         value: value)
        let cell = ChartSettingsCell(type: type)
        cell.boolean.value = value
        bind(cell.boolean, fire: false) { [weak self] observer, value in
            guard let value = value else { return }
            observer.settings.chartDownsamplingOn = !value
            self?.ruuviAppSettingsService.set(showAllData: value)
        }
        return cell
    }

    private func buildChartDotsDrawing() -> ChartSettingsCell {
        let title = "ChartSettings.DrawDots.title".localized()
        let value = settings.chartDrawDotsOn
        let type: ChartSettingsCellType = .switcher(title: title,
                         value: value)
        let cell = ChartSettingsCell(type: type)
        cell.boolean.value = value
        bind(cell.boolean, fire: false) { [weak self] observer, value in
            guard let value = value else { return }
            observer.settings.chartDrawDotsOn = value
            self?.ruuviAppSettingsService.set(drawDots: value)
        }
        return cell
    }

    private func buildChartHistory() -> ChartSettingsCell {
        let title = "ChartSettings.Duration.title".localized()
        let value = settings.chartDurationHours / 24
        let unitSingular = ChartSettingsIntegerUnit.day
        let unitPlural = ChartSettingsIntegerUnit.days
        let type: ChartSettingsCellType = .stepper(
            title: title,
            value: value,
            unitSingular: unitSingular,
            unitPlural: unitPlural
        )
        let cell = ChartSettingsCell(type: type)
        cell.integer.value = value
        bind(cell.integer, fire: false) { [weak self] observer, value in
            guard let value = value else { return }
            observer.settings.chartDurationHours = value * 24
            self?.invalidateTimer()
            self?.scheduleChartDurationSettingsRequest()
        }
        return cell
    }

    /// Sync the chart duration on cloud after four four of value being changed.
    /// This method avoid making several requests when user changes the stepped value.
    private func scheduleChartDurationSettingsRequest() {
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true, block: { [weak self] (_) in
            guard let self = self else { return }
            self.syncChartDuratingSettings()
        })
    }
    /// Invalidates the running timer
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
    /// This method syncs the local settings to the cloud
    private func syncChartDuratingSettings() {
        ruuviAppSettingsService.set(chartDuration: settings.chartDurationHours / 24)
        invalidateTimer()
    }
}
