import BTKit
import Foundation
import RuuviOntology
import UIKit
import DGCharts
import RuuviLocal

protocol NewCardsViewInput: ViewInput {
    var state: NewCardsViewState { get set }

    func createChartViews(from: [MeasurementType], for sensor: RuuviTagSensor)
    func setChartViewData(
        from chartViewData: [NewTagChartViewData],
        for sensor: RuuviTagSensor,
        settings: RuuviLocalSettings
    )

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
    )

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
    )

//    func applyUpdate(to viewModel: CardsViewModel)
//    func scroll(to index: Int)
//    func showBluetoothDisabled(userDeclined: Bool)
//    func showKeepConnectionDialogChart(for viewModel: CardsViewModel)
//    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel)
//    func showFirmwareUpdateDialog(for viewModel: CardsViewModel)
//    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel)
//    func showReverseGeocodingFailed()
//    func showAlreadyLoggedInAlert(with email: String)
//    func showChart(module: UIViewController)
//    func dismissChart()
//    func viewShouldDismiss()
}

extension NewCardsViewInput {
    func showChart(module _: UIViewController) {}
    func dismissChart() {}
}
