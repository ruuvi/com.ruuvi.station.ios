import Foundation

protocol TagChartViewOutput: AnyObject {
    func didChartChangeVisibleRange(_ chartView: TagChartView, newRange range:(min: TimeInterval, max: TimeInterval))
    func chartDidTranslate(_ chartView: TagChartView)
    func chartDidScale(_ chartView: TagChartView)
}
