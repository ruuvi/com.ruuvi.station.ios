import UIKit
import Charts

class TagChartsView: UIView {
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureChart: LineChartView!
    @IBOutlet weak var humidityChart: LineChartView!
    @IBOutlet weak var pressureChart: LineChartView!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
}
