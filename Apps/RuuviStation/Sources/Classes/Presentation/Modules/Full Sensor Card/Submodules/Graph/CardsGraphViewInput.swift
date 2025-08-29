import BTKit
import DGCharts
import Foundation
import RuuviLocal
import RuuviOntology

protocol CardsGraphViewInput: ViewInput {
    var historyLengthInHours: Int { get set }
    var showChartStat: Bool { get set }
    var compactChartView: Bool { get set }
    var showChartAll: Bool { get set }
    var showAlertRangeInGraph: Bool { get set }
    var viewIsVisible: Bool { get }
    func resetScrollPosition()
    func showBluetoothDisabled(userDeclined: Bool)
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot?)
    func createChartViews(from: [MeasurementType])
    func scroll(to measurementType: MeasurementType)
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
    func showClearConfirmationDialog(for snapshot: RuuviTagCardSnapshot)
    func setSync(progress: BTServiceProgress?, for snapshot: RuuviTagCardSnapshot)
    func setSyncProgressViewHidden()
    func showFailedToSyncIn()
    func showSwipeUpInstruction()
    func showSyncConfirmationDialog(for snapshot: RuuviTagCardSnapshot)
    func showSyncAbortAlert(source: GraphHistoryAbortSyncSource)
    func showSyncAbortAlertForSwipe(to index: Int)
    func showExportSheet(with path: URL)
    func showLongerHistoryDialog()
}
