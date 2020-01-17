import UIKit
import Nantes
import Localize_Swift

class HumidityCalibrationViewController: UIViewController {
    var output: HumidityCalibrationViewOutput!

    @IBOutlet weak var targetHumidityLabel: UILabel!
    @IBOutlet weak var descriptionLabel: NantesLabel!
    @IBOutlet weak var oldHumidityLabel: UILabel!
    @IBOutlet weak var lastCalibrationDateLabel: UILabel!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var calibrateButton: UIButton!

    var oldHumidity: Double = 0 { didSet { updateUIOldHumidity() } }
    var humidityOffset: Double = 0 { didSet { updateUIHumidityOffset() } }
    var lastCalibrationDate: Date? { didSet { updateUILastCalibrationDate() } }

    // swiftlint:disable line_length
    private let videoTutorialsUrl = URL(string: "https://www.youtube.com/results?search_query=hygrometer+salt+calibration")!
    // swiftlint:enable line_length
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
        targetHumidityLabel.text = String.localizedStringWithFormat("%.2f", 75.0)
    }

    func showClearCalibrationConfirmationDialog() {
        let title = "HumidityCalibration.ClearCalibrationConfirmationAlert.title".localized()
        let message = "HumidityCalibration.ClearCalibrationConfirmationAlert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
                                           style: .destructive,
                                           handler: { [weak self] _ in
            self?.output.viewDidConfirmToClearHumidityOffset()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showCalibrationConfirmationDialog() {
        let title = "HumidityCalibration.CalibrationConfirmationAlert.title".localized()
        let message = "HumidityCalibration.CalibrationConfirmationAlert.message".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
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

// MARK: - NantesLabelDelegate
extension HumidityCalibrationViewController: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        if link.absoluteString == videoTutorialsUrl.absoluteString {
            UIApplication.shared.open(link)
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
                let format = "HumidityCalibration.lastCalibrationDate.format".localized()
                lastCalibrationDateLabel.text = String.localizedStringWithFormat(format,
                                                                                 df.string(from: lastCalibrationDate))
                clearButton.isEnabled = true
            } else {
                lastCalibrationDateLabel.text = nil
                clearButton.isEnabled = false
            }
        }
    }

    private func updateUIOldHumidity() {
        if isViewLoaded {
            oldHumidityLabel.text = String.localizedStringWithFormat("%.2f", oldHumidity + humidityOffset) + " %"
        }
    }

    func updateUIHumidityOffset() {
        if isViewLoaded {
            oldHumidityLabel.text = String.localizedStringWithFormat("%.2f", oldHumidity + humidityOffset) + " %"
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
            descriptionLabel.addLink(to: videoTutorialsUrl, withRange: NSRange(linkRange, in: text))
            let color = UIColor(red: 0.0/255.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)
            descriptionLabel.linkAttributes = [NSAttributedString.Key.foregroundColor: color]
        }
        descriptionLabel.delegate = self
    }
}
