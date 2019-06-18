import UIKit
import Charts

class ChartViewController: UIViewController {
    var output: ChartViewOutput!

    @IBOutlet weak var chartView: LineChartView!
    
}

extension ChartViewController: ChartViewInput {
    
}
