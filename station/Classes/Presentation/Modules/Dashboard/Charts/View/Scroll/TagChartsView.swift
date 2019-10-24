import UIKit
import Charts

protocol TagChartsViewDelegate: class {
    func tagCharts(view: TagChartsView, sync sender: Any)
    func tagCharts(view: TagChartsView, delete sender: Any)
    func tagCharts(view: TagChartsView, upload sender: Any)
}

class TagChartsView: UIView {
    weak var delegate: TagChartsViewDelegate?
    
    @IBOutlet weak var buttonsContainer: UIView!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureChart: LineChartView!
    @IBOutlet weak var humidityChart: LineChartView!
    @IBOutlet weak var pressureChart: LineChartView!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityUnitLabel: UILabel!
    @IBOutlet weak var pressureUnitLabel: UILabel!
    
    @IBAction func syncButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, sync: sender)
    }
    
    @IBAction func uploadButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, upload: sender)
    }
    
    @IBAction func deleteButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, delete: sender)
    }
}
