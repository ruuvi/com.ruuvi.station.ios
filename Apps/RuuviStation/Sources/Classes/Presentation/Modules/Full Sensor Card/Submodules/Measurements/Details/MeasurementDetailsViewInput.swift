import Foundation
import DGCharts
import RuuviLocal
import RuuviOntology
import RuuviService

protocol MeasurementDetailsViewInput: ViewInput {
    func updateMeasurements(with indicatorData: RuuviTagCardSnapshotDisplayData?)
    func setChartData(
        _ data: RuuviGraphViewDataModel,
        settings: RuuviLocalSettings,
        displayType: MeasurementType,
        unit: String,
        measurementService: RuuviServiceMeasurement
    )
    func updateChartData(_ entries: [ChartDataEntry], settings: RuuviLocalSettings)
    func setNoDataLabelVisibility(show: Bool)
}
