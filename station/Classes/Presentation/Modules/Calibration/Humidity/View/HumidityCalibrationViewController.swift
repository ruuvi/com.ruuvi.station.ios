import UIKit
import TTTAttributedLabel

class HumidityCalibrationViewController: UIViewController {
    var output: HumidityCalibrationViewOutput!
    
    @IBOutlet weak var descriptionLabel: TTTAttributedLabel!
    @IBOutlet weak var oldHumidityLabel: UILabel!
    @IBOutlet weak var lastCalibrationDateLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    
    var oldHumidity: Double = 0 { didSet { updateUIOldHumidity() } }
    var humidityOffset: Double = 0 { didSet { updateUIHumidityOffset() } }
    var lastCalibrationDate: Date? { didSet { updateUILastCAlibrationDate() } }
    
    private let videoTutorialsUrl = URL(string: "https://www.youtube.com/results?search_query=hygrometer+salt+calibration")!
}

// MARK: - HumidityCalibrationViewInput
extension HumidityCalibrationViewController: HumidityCalibrationViewInput {
    func localize() {
        
    }
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension HumidityCalibrationViewController {
    @IBAction func cancelButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerCancel()
    }
    
    @IBAction func calibrateButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerCalibrate()
    }
    
    @IBAction func clearButtonTouchUpInside(_ sender: Any) {
        
    }
}

// MARK: - View lifecycle
extension HumidityCalibrationViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
        updateUI()
        output.viewDidLoad()
    }
}

// MARK: - TTTAttributedLabelDelegate
extension HumidityCalibrationViewController: TTTAttributedLabelDelegate {
    func attributedLabel(_ label: TTTAttributedLabel!, didSelectLinkWith url: URL!) {
        if url.absoluteString == videoTutorialsUrl.absoluteString {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Update UI
extension HumidityCalibrationViewController {
    private func updateUI() {
        updateUIOldHumidity()
        updateUIHumidityOffset()
        updateUILastCAlibrationDate()
    }
    
    private func updateUILastCAlibrationDate() {
        if isViewLoaded {
            if let lastCalibrationDate = lastCalibrationDate {
                let df = DateFormatter()
                df.dateFormat = "dd MMMM yyyy"
                lastCalibrationDateLabel.text = String(format: "HumidityCalibration.lastCalibrationDate.format".localized(), df.string(from: lastCalibrationDate))
                clearButton.isEnabled = true
            } else {
                lastCalibrationDateLabel.text = nil
                clearButton.isEnabled = false
            }
        }
    }
    
    private func updateUIOldHumidity() {
        if isViewLoaded {
            oldHumidityLabel.text = String(format: "%.2f", oldHumidity + humidityOffset) + " %"
        }
    }
    
    func updateUIHumidityOffset() {
        if isViewLoaded {
            oldHumidityLabel.text = String(format: "%.2f", oldHumidity + humidityOffset) + " %"
        }
    }
}

// MARK: - View configuration
extension HumidityCalibrationViewController {
    private func configureViews() {
        let text = "HumidityCalibration.Description.text".localized()
        descriptionLabel.text = text
        let link = "HumidityCalibration.VideoTutorials.link".localized()
        if let linkRange = text.range(of: link) {
            descriptionLabel.addLink(to: videoTutorialsUrl, with: NSRange(linkRange, in: text))
        }
        descriptionLabel.delegate = self
    }
}
