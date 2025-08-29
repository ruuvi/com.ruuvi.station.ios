import Foundation
import DGCharts
import RuuviLocal
import RuuviOntology

protocol MeasurementDetailsViewInput: ViewInput {
    func setChartData(_ data: TagChartViewData, settings: RuuviLocalSettings)
    func updateChartData(_ entries: [ChartDataEntry], settings: RuuviLocalSettings)
    func setNoDataLabelVisibility(show: Bool)
}
