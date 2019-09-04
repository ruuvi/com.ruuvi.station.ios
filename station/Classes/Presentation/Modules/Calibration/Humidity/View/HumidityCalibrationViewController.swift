import UIKit
import TTTAttributedLabel
import Localize_Swift

class HumidityCalibrationViewController: UIViewController {
    var output: HumidityCalibrationViewOutput!
    
    @IBOutlet weak var descriptionLabel: TTTAttributedLabel!
    @IBOutlet weak var oldHumidityLabel: UILabel!
    @IBOutlet weak var lastCalibrationDateLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var calibrateButton: UIButton!
    
    var oldHumidity: Double = 0 { didSet { updateUIOldHumidity() } }
    var humidityOffset: Double = 0 { didSet { updateUIHumidityOffset() } }
    var lastCalibrationDate: Date? { didSet { updateUILastCalibrationDate() } }
    
    private let videoTutorialsUrl = URL(string: "https://www.youtube.com/results?search_query=hygrometer+salt+calibration")!
}

// MARK: - HumidityCalibrationViewInput
extension HumidityCalibrationViewController: HumidityCalibrationViewInput {
    func localize() {
        configureDescriptionLabel()
        updateUILastCalibrationDate()
        noteLabel.text = "HumidityCalibration.Label.note.text".localized()
        clearButton.setTitle("HumidityCalibration.Button.Clear.title".localized(), for: .normal)
        calibrateButton.setTitle("HumidityCalibration.Button.Calibrate.title".localized(), for: .normal)
        closeButton.setTitle("HumidityCalibration.Button.Close.title".localized(), for: .normal)
    }
    func apply(theme: Theme) {
        
    }
    
    func showClearCalibrationConfirmationDialog() {
        let controller = UIAlertController(title: "HumidityCalibration.ClearCalibrationConfirmationAlert.title".localized(), message: "HumidityCalibration.ClearCalibrationConfirmationAlert.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmToClearHumidityOffset()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showCalibrationConfirmationDialog() {
        let controller = UIAlertController(title: "HumidityCalibration.CalibrationConfirmationAlert.title".localized(), message: "HumidityCalibration.CalibrationConfirmationAlert.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToCalibrateHumidityOffset()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - IBActions
extension HumidityCalibrationViewController {
    @IBAction func closeButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerClose()
    }
    
    @IBAction func calibrateButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerCalibrate()
    }
    
    @IBAction func clearButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerClearCalibration()
    }
}

// MARK: - View lifecycle
extension HumidityCalibrationViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
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
        updateUILastCalibrationDate()
    }
    
    private func updateUILastCalibrationDate() {
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
        configureDescriptionLabel()
    }
    
    private func configureDescriptionLabel() {
        let text = "HumidityCalibration.Description.text".localized()
        descriptionLabel.text = text
        let link = "HumidityCalibration.VideoTutorials.link".localized()
        if let linkRange = text.range(of: link) {
            descriptionLabel.addLink(to: videoTutorialsUrl, with: NSRange(linkRange, in: text))
        }
        descriptionLabel.delegate = self
    }
}
