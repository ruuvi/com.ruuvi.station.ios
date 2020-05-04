import Foundation
import Charts

struct TagChartViewModel {
    var unit: Observable<Unit?> = Observable<Unit?>()
    var chartData: Observable<LineChartData?> = Observable<LineChartData?>()
    var progress: Observable<Float?> = Observable<Float?>()
}
