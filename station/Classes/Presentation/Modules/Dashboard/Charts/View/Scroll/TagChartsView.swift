import UIKit
import Charts

protocol TagChartsViewDelegate: class {
    func tagCharts(view: TagChartsView, didTriggerCards sender: Any)
    func tagCharts(view: TagChartsView, didTriggerSettings sender: Any)
    func tagCharts(view: TagChartsView, didTriggerClear sender: Any)
    func tagCharts(view: TagChartsView, didTriggerSync sender: Any)
    func tagCharts(view: TagChartsView, didTriggerExport sender: Any)
}

class TagChartsView: UIView, Localizable, UIScrollViewDelegate {
    weak var delegate: TagChartsViewDelegate?
    
    @IBOutlet weak var alertImageView: UIImageView!
    @IBOutlet weak var alertView: UIView!
    @IBOutlet weak var iPadDefaultConstraint: NSLayoutConstraint!
    @IBOutlet weak var iPadLandscapeConstraint: NSLayoutConstraint!
    @IBOutlet weak var iPadPortraitConstraint: NSLayoutConstraint!
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
    @IBOutlet weak var scrollView: UIScrollView!
    
    private var contentOffset: CGPoint = .zero
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
        iPadDefaultConstraint.isActive = false
        NotificationCenter.default.addObserver(self, selector: #selector(TagChartsView.handleRotation(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc private func handleRotation(_ notification: Notification) {
        if UIDevice.current.orientation.isLandscape {
            scrollView.setContentOffset(contentOffset, animated: false)
        }
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        contentOffset = scrollView.contentOffset
    }
    
    // MARK: - Localizable
    func localize() {
        clearButton.setTitle("TagCharts.Clear.title".localized(), for: .normal)
        syncButton.setTitle("TagCharts.Sync.title".localized(), for: .normal)
        exportButton.setTitle("TagCharts.Export.title".localized(), for: .normal)
        pressureUnitLabel.text = "hPa".localized()
    }
    
    // MARK: - IBActions
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
