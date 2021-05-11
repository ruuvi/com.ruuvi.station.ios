import Foundation

protocol TagChartModuleOutput: AnyObject {
    var dataSource: [RuuviMeasurement] { get }
    var lastMeasurement: RuuviMeasurement? { get }
    func chartViewDidChangeViewPort(_ chartView: TagChartView)
}
