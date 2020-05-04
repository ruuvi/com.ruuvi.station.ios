import UIKit
import Charts

protocol TagChartViewInput: ViewInput {
    func clearChartData()
    func fitZoomTo(min: TimeInterval, max: TimeInterval)
    func fitScreen()
    func reloadData()
    func setXRange(min: TimeInterval, max: TimeInterval)
    func resetCustomAxisMinMax()
}
