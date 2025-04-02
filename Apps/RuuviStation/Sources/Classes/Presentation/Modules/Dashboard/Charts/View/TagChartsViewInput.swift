import BTKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology

protocol TagChartsViewInput: ViewInput {
    var viewModel: TagChartsViewModel { get set }
    var historyLengthInHours: Int { get set }
    var showChartStat: Bool { get set }
    var compactChartView: Bool { get set }
    var showChartAll: Bool { get set }
    var showAlertRangeInGraph: Bool { get set }
    var useNewGraphRendering: Bool { get set }
    var viewIsVisible: Bool { get }
    func createChartViews(from: [MeasurementType])
    func clearChartHistory()
    func setChartViewData(
        from chartViewData: [TagChartViewData],
        settings: RuuviLocalSettings
    )

    // swiftlint:disable:next function_parameter_count
    func updateChartViewData(
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
        firstEntry: RuuviMeasurement?,
        settings: RuuviLocalSettings
    )

    // swiftlint:disable:next function_parameter_count
    func updateLatestMeasurement(
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
    )
    func updateLatestRecordStatus(with record: RuuviTagSensorRecord)
    func showBluetoothDisabled(userDeclined: Bool)
    func showClearConfirmationDialog(for viewModel: TagChartsViewModel)
    func setSync(progress: BTServiceProgress?, for viewModel: TagChartsViewModel)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn()
    func showSwipeUpInstruction()
    func showSyncConfirmationDialog(for viewModel: TagChartsViewModel)
    func showSyncAbortAlert(dismiss: Bool)
    func showSyncAbortAlertForSwipe()
    func showExportSheet(with path: URL)
    func showLongerHistoryDialog()
}
