import Foundation

protocol TagChartViewOutput: AnyObject {
    func didChartChangeVisibleRange(_ chartView: TagChartView, newRange range:(min: TimeInterval, max: TimeInterval))
}
