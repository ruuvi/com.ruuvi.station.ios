import Foundation

protocol TagChartViewOutput: class {
    func didChartChangeVisibleRange(_ chartView: TagChartView, newRange range:(min: TimeInterval, max: TimeInterval))
}
