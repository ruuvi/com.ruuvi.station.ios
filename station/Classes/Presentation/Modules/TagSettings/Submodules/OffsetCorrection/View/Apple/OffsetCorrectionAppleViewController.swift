import UIKit
import RuuviOntology

class OffsetCorrectionAppleViewController: UIViewController {
    var output: OffsetCorrectionViewOutput!

    var measurementService: MeasurementsService!

    var viewModel = OffsetCorrectionViewModel() {
        didSet {
            bindViewModel()
        }
    }

    @IBOutlet weak var correctedValueTitle: UILabel!
    @IBOutlet weak var originalValueTitle: UILabel!
    @IBOutlet weak var descriptionTextView: UITextView!
    @IBOutlet weak var originalValueLabel: UILabel!
    @IBOutlet weak var originalValueUpdateTimeLabel: UILabel!
    @IBOutlet weak var correctedValueLabel: UILabel!
    @IBOutlet weak var offsetValueLabel: UILabel!
    @IBOutlet weak var correctedValueView: UIView!
    @IBOutlet weak var calibrateButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!

    private var timer: Timer?
    private var updatedAt: Date?

    deinit {
        timer?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            if let updateAt = self?.updatedAt {
                self?.originalValueUpdateTimeLabel.text = updateAt.ruuviAgo()
            }
        })
        bindViewModel()

        output.viewDidLoad()
    }

    private func bindViewModel() {
        if isViewLoaded {
            bindLabels()
            bindViews()
        }
    }
    private func bindViews() {
        correctedValueView.bind(viewModel.hasOffsetValue) {[weak self] _, hasValue in
            if let hasValue = hasValue, hasValue == true {
                self?.correctedValueView.isHidden = false
                self?.clearButton.isEnabled = true
                self?.clearButton.backgroundColor = .normalButton
            } else {
                self?.correctedValueView.isHidden = true
                self?.clearButton.backgroundColor = .disableButton
                self?.clearButton.isEnabled = false
            }
        }
    }
    private func bindLabels() {
        originalValueLabel.bind(viewModel.originalValue) { [weak self] label, value in
            switch self?.viewModel.type {
            case .humidity:
                label.text = "\((value.bound * 100).round(to: 2))\("%".localized())"
            case .pressure:
                label.text = self?.measurementService.string(for: Pressure(value, unit: .hectopascals))
            default:
                label.text = self?.measurementService.string(for: Temperature(value, unit: .celsius))
            }
        }
        originalValueUpdateTimeLabel.bind(viewModel.updateAt) {[weak self] _, date in
            if let date = date {
                self?.updatedAt = date
            }
        }
        offsetValueLabel.bind(viewModel.offsetCorrectionValue) { [weak self] label, value in
            let text: String?
            switch self?.viewModel.type {
            case .humidity:
                text = self?.measurementService.humidityOffsetCorrectionString(for: value ?? 0)
            case .pressure:
                text = self?.measurementService.pressureOffsetCorrectionString(for: value ?? 0)
            default:
                text = self?.measurementService.temperatureOffsetCorrectionString(for: value ?? 0)
            }

            label.text = "(\(text!))"
        }
        correctedValueLabel.bind(viewModel.correctedValue) { [weak self] label, value in
            switch self?.viewModel.type {
            case .humidity:
                label.text = "\((value.bound * 100).round(to: 2))\("%".localized())"
            case .pressure:
                label.text = self?.measurementService.string(for: Pressure(value, unit: .hectopascals))
            default:
                label.text = self?.measurementService.string(for: Temperature(value, unit: .celsius))
            }
        }
    }
}

extension OffsetCorrectionAppleViewController: OffsetCorrectionViewInput {
    func localize() {
        configDescriptionContent()
        correctedValueTitle.text = "OffsetCorrection.CorrectedValue.title".localized()
        originalValueTitle.text = "OffsetCorrection.OriginalValue.title".localized()
        calibrateButton.setTitle("HumidityCalibration.Button.Calibrate.title".localized(), for: .normal)
        clearButton.setTitle("HumidityCalibration.Button.Clear.title".localized(), for: .normal)
        self.title = self.viewModel.title
    }

    private func configDescriptionContent() {
        let text = "OffsetCorrection.CalibrationDescription.text".localized()

        let attrString = NSMutableAttributedString(string: text)
        let muliRegular = UIFont.systemFont(ofSize: 16)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(NSAttributedString.Key.font, value: muliRegular, range: range)
        // make text color gray
        attrString.addAttribute(.foregroundColor,
            value: UIColor.darkGray,
            range: NSRange(location: 0, length: attrString.length))

        descriptionTextView.attributedText = attrString
    }

    func showCalibrateDialog() {
        let title = "OffsetCorrection.Dialog.Calibration.Title".localized()
        var message = ""
        switch self.viewModel.type {
        case .humidity:
            message = "OffsetCorrection.Dialog.Calibration.EnterHumidity".localizedFormat("%".localized())
        case .pressure:
            let unit = self.viewModel.pressureUnit.value ?? .hectopascals
            message = "OffsetCorrection.Dialog.Calibration.EnterPressure".localizedFormat(unit.symbol)
        default:
            let unit = self.viewModel.temperatureUnit.value ?? .celsius
            message = "OffsetCorrection.Dialog.Calibration.EnterTemperature".localizedFormat(unit.symbol)
        }

        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addTextField { textfield in
            textfield.keyboardType = .decimalPad
        }
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
            style: .destructive,
            handler: { [weak self] _ in
                let text = controller.textFields?.first?.text ?? "0.0"
                self?.output.viewDidSetCorrectValue(correctValue: text.doubleValue)
            }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showClearConfirmationDialog() {
        let title = "OffsetCorrection.Dialog.Calibration.Title".localized()
        let message = "OffsetCorrection.Dialog.Calibration.ClearConfirm".localized()
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(),
            style: .destructive,
            handler: { [weak self] _ in
                self?.output.viewDidClearOffsetValue()
            }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
}

// MARK: - IBOutlet
extension OffsetCorrectionAppleViewController {
    @IBAction func calibrateButtonAction(_ sender: Any) {
        output.viewDidOpenCalibrateDialog()
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        output.viewDidOpenClearDialog()
    }
}
