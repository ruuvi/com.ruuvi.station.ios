import UIKit
import Charts

protocol TagChartsViewDelegate: class {
    func tagCharts(view: TagChartsView, didTriggerCards sender: Any)
    func tagCharts(view: TagChartsView, didTriggerSettings sender: Any)
    func tagCharts(view: TagChartsView, didTriggerClear sender: Any)
    func tagCharts(view: TagChartsView, didTriggerSync sender: Any)
    func tagCharts(view: TagChartsView, didTriggerExport sender: Any)
}

class TagChartsView: UIView, Localizable {
    weak var delegate: TagChartsViewDelegate?
    
    @IBOutlet weak var syncStatusLabel: UILabel!
    @IBOutlet weak var backgroundImage: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var temperatureChart: LineChartView!
    @IBOutlet weak var humidityChart: LineChartView!
    @IBOutlet weak var pressureChart: LineChartView!
    @IBOutlet weak var temperatureUnitLabel: UILabel!
    @IBOutlet weak var humidityUnitLabel: UILabel!
    @IBOutlet weak var pressureUnitLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }
    
    func localize() {
        clearButton.setTitle("TagCharts.Clear.title".localized(), for: .normal)
        syncButton.setTitle("TagCharts.Sync.title".localized(), for: .normal)
        exportButton.setTitle("TagCharts.Export.title".localized(), for: .normal)
    }
    
    @IBAction func exportButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerExport: sender)
    }
    
    @IBAction func syncButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerSync: sender)
    }
    
    @IBAction func clearButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerClear: sender)
    }
    
    @IBAction func cardsButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerCards: sender)
    }
    
    @IBAction func settingsButtonTouchUpInside(_ sender: Any) {
        delegate?.tagCharts(view: self, didTriggerSettings: sender)
    }
}
