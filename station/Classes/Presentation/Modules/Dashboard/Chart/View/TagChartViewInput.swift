import UIKit
import Charts

protocol TagChartViewInput: ViewInput {
    var chartView: TagChartView { get }
    func configure(with viewModel: TagChartViewModel)
    func clearChartData()
    func fitZoomTo(min: TimeInterval, max: TimeInterval)
    func fitScreen()
    func reloadData()
    func setXRange(min: TimeInterval, max: TimeInterval)
    func setYAxisLimit(min: Double, max: Double)
    func resetCustomAxisMinMax()
}
