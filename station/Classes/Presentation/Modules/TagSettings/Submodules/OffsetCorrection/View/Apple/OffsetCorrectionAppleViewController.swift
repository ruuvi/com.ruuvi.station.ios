import UIKit
import RuuviOntology
import RuuviLocalization
import RuuviService
#if canImport(RuuviServiceMeasurement)
import RuuviServiceMeasurement
#endif

class OffsetCorrectionAppleViewController: UIViewController {
    var output: OffsetCorrectionViewOutput!

    var measurementService: RuuviServiceMeasurement!

    var viewModel = OffsetCorrectionViewModel() {
        didSet {
            bindViewModel()
        }
    }

    private lazy var backButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAssets.backButtonImage
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

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

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            if let updateAt = self?.updatedAt {
                self?.originalValueUpdateTimeLabel.text = "(\(updateAt.ruuviAgo()))"
            }
        })
        bindViewModel()

        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(top: backBarButtonItemView.topAnchor,
                          leading: backBarButtonItemView.leadingAnchor,
                          bottom: backBarButtonItemView.bottomAnchor,
                          trailing: backBarButtonItemView.trailingAnchor,
                          padding: .init(top: 0, left: -12, bottom: 0, right: 0),
                          size: .init(width: 40, height: 40))
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)

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
                self?.clearButton.alpha = 1
            } else {
                self?.correctedValueView.isHidden = true
                self?.clearButton.isEnabled = false
                self?.clearButton.alpha = 0.3
            }
        }
    }
    private func bindLabels() {
        originalValueLabel.bind(viewModel.originalValue) { [weak self] label, value in
            switch self?.viewModel.type {
            case .humidity:
                label.text = "\((value.bound * 100).round(to: 2))%)"
            case .pressure:
                label.text = self?.measurementService.string(for: Pressure(value, unit: .hectopascals),
                                                             allowSettings: false)
            default:
                label.text = self?.measurementService.string(for: Temperature(value, unit: .celsius),
                                                             allowSettings: false)
            }
        }
        originalValueUpdateTimeLabel.bind(viewModel.updateAt) {[weak self] label, date in
            if let date = date {
                self?.updatedAt = date
                label.text = "(\(date.ruuviAgo()))"
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
                label.text = "\((value.bound * 100).round(to: 2))%"
            case .pressure:
                label.text = self?.measurementService.string(for: Pressure(value, unit: .hectopascals),
                                                             allowSettings: false)
            default:
                label.text = self?.measurementService.string(for: Temperature(value, unit: .celsius),
                                                             allowSettings: false)
            }
        }
    }
}

extension OffsetCorrectionAppleViewController: OffsetCorrectionViewInput {
    func localize() {
        configDescriptionContent()
        correctedValueTitle.text = RuuviLocalization.OffsetCorrection.CorrectedValue.title
        originalValueTitle.text = RuuviLocalization.OffsetCorrection.OriginalValue.title
        calibrateButton.setTitle(RuuviLocalization.HumidityCalibration.Button.Calibrate.title, for: .normal)
        clearButton.setTitle(RuuviLocalization.HumidityCalibration.Button.Clear.title, for: .normal)
        self.title = self.viewModel.title
    }

    private func configDescriptionContent() {
            let text = RuuviLocalization.OffsetCorrection.CalibrationDescription.text

        let attrString = NSMutableAttributedString(string: text)
        let muliRegular = UIFont.Muli(.regular, size: 16)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(NSAttributedString.Key.font, value: muliRegular, range: range)
        // make text color gray
        attrString.addAttribute(.foregroundColor,
            value: RuuviColor.ruuviTextColor ?? UIColor.secondaryLabel,
            range: NSRange(location: 0, length: attrString.length))

        descriptionTextView.attributedText = attrString
        descriptionTextView.textColor = RuuviColor.ruuviTextColor
    }

    func showCalibrateDialog() {
        let title = RuuviLocalization.OffsetCorrection.Dialog.Calibration.title
        var message = ""
        switch self.viewModel.type {
        case .humidity:
            message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterHumidity("%")
        case .pressure:
            let format = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterPressure
            let unit = self.viewModel.pressureUnit.value ?? .hectopascals
            message = format(unit.symbol)
        default:
            let format = RuuviLocalization.OffsetCorrection.Dialog.Calibration.enterTemperature
            let unit = self.viewModel.temperatureUnit.value ?? .celsius
            message = format(unit.symbol)
        }

        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addTextField { textfield in
            textfield.keyboardType = .numbersAndPunctuation
        }
             controller.addAction(UIAlertAction(title: RuuviLocalization.confirm,
            style: .destructive,
            handler: { [weak self] _ in
                let text = controller.textFields?.first?.text ?? "0.0"
                self?.output.viewDidSetCorrectValue(correctValue: text.doubleValue)
            }))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showClearConfirmationDialog() {
        let title = RuuviLocalization.OffsetCorrection.Dialog.Calibration.title
        let message = RuuviLocalization.OffsetCorrection.Dialog.Calibration.clearConfirm
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: RuuviLocalization.confirm,
            style: .destructive,
            handler: { [weak self] _ in
                self?.output.viewDidClearOffsetValue()
            }))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
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

    @objc fileprivate func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}
